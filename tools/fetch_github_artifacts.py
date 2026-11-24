#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import subprocess
import tempfile
import urllib.error
import urllib.request
from pathlib import Path


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def request_json(url, token):
    req = urllib.request.Request(url, headers={
        "Accept": "application/vnd.github+json",
        "Authorization": f"Bearer {token}",
        "User-Agent": "dopamine-audit-artifact-fetcher",
        "X-GitHub-Api-Version": "2022-11-28",
    })
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"GitHub API request failed: HTTP {exc.code}") from None


def open_download(url, token):
    req = urllib.request.Request(url, headers={
        "Accept": "application/vnd.github+json",
        "Authorization": f"Bearer {token}",
        "User-Agent": "dopamine-audit-artifact-fetcher",
        "X-GitHub-Api-Version": "2022-11-28",
    })
    opener = urllib.request.build_opener(NoRedirect())
    try:
        return opener.open(req, timeout=120)
    except urllib.error.HTTPError as exc:
        if exc.code not in (301, 302, 303, 307, 308):
            raise RuntimeError(f"Artifact API request failed: HTTP {exc.code}") from None
        location = exc.headers.get("Location")
        if not location:
            raise RuntimeError("Artifact API redirect omitted its signed download URL") from None
        try:
            return urllib.request.urlopen(location, timeout=180)
        except urllib.error.HTTPError as download_error:
            raise RuntimeError(f"Artifact storage download failed: HTTP {download_error.code}") from None


def save_artifact(repo, artifact, token, out_dir):
    name = Path(artifact["name"]).name
    if name != artifact["name"] or name in ("", ".", ".."):
        raise RuntimeError(f"Unsafe artifact name: {artifact['name']!r}")
    destination = out_dir / name
    digest = hashlib.sha256()
    size = 0
    url = f"https://api.github.com/repos/{repo}/actions/artifacts/{artifact['id']}/zip"
    with open_download(url, token) as response:
        fd, temporary = tempfile.mkstemp(prefix=f".{name}.", dir=out_dir)
        try:
            with os.fdopen(fd, "wb") as output:
                while True:
                    chunk = response.read(1024 * 1024)
                    if not chunk:
                        break
                    output.write(chunk)
                    digest.update(chunk)
                    size += len(chunk)
            expected = artifact.get("digest") or ""
            actual = f"sha256:{digest.hexdigest()}"
            if expected and actual.lower() != expected.lower():
                raise RuntimeError(f"Digest mismatch for artifact {name}: expected {expected}, got {actual}")
            if size != artifact["size_in_bytes"]:
                raise RuntimeError(f"Size mismatch for artifact {name}: expected {artifact['size_in_bytes']}, got {size}")
            os.replace(temporary, destination)
        except BaseException:
            try:
                os.unlink(temporary)
            except FileNotFoundError:
                pass
            raise
    return {"id": artifact["id"], "name": name, "size": size, "sha256": digest.hexdigest(), "path": str(destination)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--out-dir", required=True)
    args = parser.parse_args()
    token = subprocess.check_output(["gh", "auth", "token"], text=True).strip()
    out_dir = Path(args.out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    data = request_json(f"https://api.github.com/repos/{args.repo}/actions/runs/{args.run_id}/artifacts", token)
    results = []
    for artifact in data.get("artifacts", []):
        if artifact.get("expired"):
            raise RuntimeError(f"Artifact expired: {artifact['name']}")
        results.append(save_artifact(args.repo, artifact, token, out_dir))
    print(json.dumps({"repo": args.repo, "run_id": args.run_id, "artifacts": results}, indent=2))


if __name__ == "__main__":
    main()
