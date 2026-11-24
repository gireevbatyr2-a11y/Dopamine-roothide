# Graphify query evidence

Graphify query is a local traversal of the saved AST graph; it does not prove behavior where the extractor missed source or symbols.

## Q1

**Question:** How does the app launch path connect main.m, app/scene delegates, the jailbreak UI action, and DOJailbreaker runJailbreak?

**Exit code:** 0

```text
Graph: Dopamine-roothide-reconstruction-9617d75f-20261124T024805Z/evidence/source/graphify/graph.json (6291 nodes) | Traversal: BFS depth=3 | Start: ['DOJailbreaker', 'path', '-action', 'main()', 'launchdhook/src/main.m', 'connection.h', '-scenewillConnectToSessionoptions', 'jailbreakd.c', 'AppleNeuralEngine.h', 'DOSceneDelegate'] | 1758 nodes found

[!] TRUNCATED: showing 144 of 1758 nodes (~5000-token budget). The answer may be among the 1614 cut nodes — raise the token budget to 55951 to get all 1758 (CLI: --budget 55951, MCP: token_budget=55951) or narrow the query (e.g. context_filter=['call'], or get_node for a specific symbol).

NODE DOJailbreaker [src=Application/Dopamine/Jailbreak/DOJailbreaker.h loc=L14 community=71]
NODE main() [src=BaseBin/XPF/external/img4lib/lzfse/src/lzfse_main.c loc=L107 community=162]
NODE path [src=Standalone/Corellium/dopamine.js loc=L6 community=151]
NODE launchdhook/src/main.m [src=BaseBin/launchdhook/src/main.m loc=L1 community=2]
NODE -scenewillConnectToSessionoptions [src=Application/Dopamine/App Delegates/DOSceneDelegate.m loc=L17 community=152]
NODE DOSceneDelegate [src=Application/Dopamine/App Delegates/DOSceneDelegate.h loc=L10 community=152]
NODE connection.h [src=BaseBin/_external/include/xpc/connection.h loc=L1 community=62]
NODE jailbreakd.c [src=BaseBin/libroothider/src/jailbreakd.c loc=L1 community=89]
NODE -action [src=Application/Frameworks/Preferences.framework/Headers/PSTableCell.h loc=L51 community=9]
NODE AppleNeuralEngine.h [src=Application/Dopamine/Exploits/weightBufs/exploit/AppleNeuralEngine/AppleNeuralEngine.h loc=L1 community=117]
NODE DOJailbreaker.h [src=Application/Dopamine/Jailbreak/DOJailbreaker.h loc=L1 community=62]
NODE -runWithErrordidRemoveJailbreakshowLogs [src=Application/Dopamine/Jailbreak/DOJailbreaker.h loc=L19 community=71]
NODE -applyContiguousMappingWorkaround [src=Application/Dopamine/Jailbreak/DOJailbreaker.h loc=L23 community=71]
NODE -contiguousMappingWorkaroundNeeded [src=Application/Dopamine/Jailbreak/DOJailbreaker.h loc=L22 community=71]
NODE -finalize [src=Application/Dopamine/Jailbreak/DOJailbreaker.h loc=L20 community=71]
NODE DOJailbreaker [src=BaseBin/dopamine/src/main.m loc=L48 community=225]
NODE dopamine/src/main.m [src=BaseBin/dopamine/src/main.m loc=L1 community=22]
NODE DOJailbreaker [src= loc= community=71]
NODE UIWindowSceneDelegate [src= loc= community=152]
NODE NSXPCConnection [src= loc= community=106]
NODE ref_path [src= loc= community=151]
NODE jailbreakd [src= loc= community=11]
NODE paths [src= loc= community=11]
NODE lzfse_main.c [src=BaseBin/XPF/external/img4lib/lzfse/src/lzfse_main.c loc=L1 community=10]
NODE get_time() [src=BaseBin/XPF/external/img4lib/lzfse/src/lzfse_main.c loc=L67 community=162]
NODE lzfse_reallocf() [src=BaseBin/XPF/external/img4lib/lzfse/src/lzfse_main.c loc=L58 community=162]
NODE usage() [src=BaseBin/XPF/external/img4lib/lzfse/src/lzfse_main.c loc=L88 community=10]
NODE main() [src=BaseBin/boomerang/src/main.c loc=L47 community=42]
NODE resume_launchd() [src=BaseBin/boomerang/src/main.c loc=L18 community=42]
NODE boomerang/src/main.c [src=BaseBin/boomerang/src/main.c loc=L1 community=22]
NODE main() [src=BaseBin/hookd/src/main.c loc=L217 community=182]
NODE hookd/src/main.c [src=BaseBin/hookd/src/main.c loc=L1 community=182]
NODE apply_fixup() [src=BaseBin/hookd/src/main.c loc=L71 community=182]
NODE apply_hook() [src=BaseBin/hookd/src/main.c loc=L30 community=182]
NODE server_loop() [src=BaseBin/hookd/src/main.c loc=L84 community=182]
NODE extract_task_port() [src=BaseBin/hookd/src/main.c loc=L9 community=182]
NODE main() [src=Standalone/Corellium/dopamine.js loc=L55 community=151]
NODE DOJailbreaker.m [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L1 community=22]
NODE -injectLaunchdHook [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L398 community=71]
NODE JBErrorCodeFailedLaunchdInjection [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L61 community=141]
NODE -removeJailbreak [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L555 community=71]
NODE -contiguousMappingWorks [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L826 community=71]
NODE -ensureNoDuplicateApps [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L490 community=218]
NODE -showNonDefaultSystemApps [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L328 community=71]
NODE JBErrorCodeFailedDuplicateApps [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L64 community=141]
NODE -doExploitation [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L173 community=81]
NODE -cleanUpExploits [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L245 community=71]
NODE -gatherSystemInformation [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L69 community=71]
NODE -allocatePurpleGfxMemWithSize [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L805 community=71]
NODE -buildPhysRWPrimitive [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L230 community=71]
NODE -elevatePrivileges [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L253 community=71]
NODE -finalizeBootstrapIfNeeded [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L572 community=71]
NODE -loadBasebinTrustcache [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L367 community=71]
NODE -surfaceIsContiguous [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L814 community=71]
NODE -cleanUpPostExploitation [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L577 community=71]
NODE -crashBackboardd [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L845 community=71]
NODE -crashBackboardd_15 [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L898 community=71]
NODE -ensureDevModeEnabled [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L335 community=71]
NODE JBErrorCode [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L50 community=141]
NODE JBErrorCodeFailedCleanup [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L56 community=81]
NODE JBErrorCodeFailedBasebinTrustcache [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L60 community=141]
NODE JBErrorCodeFailedBuildingPhysRW [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L55 community=141]
NODE JBErrorCodeFailedExploitation [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L54 community=141]
NODE JBErrorCodeFailedGetRoot [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L57 community=141]
NODE JBErrorCodeFailedInitFakeLib [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L63 community=141]
NODE JBErrorCodeFailedInitProtection [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L62 community=141]
NODE JBErrorCodeFailedKernelPatchfinding [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L52 community=141]
NODE JBErrorCodeFailedLoadingExploit [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L53 community=141]
NODE JBErrorCodeFailedPlatformize [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L59 community=141]
NODE JBErrorCodeFailedToFindKernel [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L51 community=141]
NODE JBErrorCodeFailedUnsandbox [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L58 community=141]
NODE main() [src=BaseBin/XPF/external/img4lib/img4.c loc=L400 community=149]
NODE apply_patch() [src=BaseBin/XPF/external/img4lib/img4.c loc=L110 community=149]
NODE -sceneDidDisconnect [src=Application/Dopamine/App Delegates/DOSceneDelegate.m loc=L43 community=152]
NODE DOSceneDelegate.m [src=Application/Dopamine/App Delegates/DOSceneDelegate.m loc=L1 community=23]
NODE -sceneDidBecomeActive [src=Application/Dopamine/App Delegates/DOSceneDelegate.m loc=L51 community=152]
NODE -sceneDidEnterBackground [src=Application/Dopamine/App Delegates/DOSceneDelegate.m loc=L69 community=152]
NODE -sceneWillEnterForeground [src=Application/Dopamine/App Delegates/DOSceneDelegate.m loc=L63 community=152]
NODE -sceneWillResignActive [src=Application/Dopamine/App Delegates/DOSceneDelegate.m loc=L57 community=152]
NODE DOSceneDelegate.h [src=Application/Dopamine/App Delegates/DOSceneDelegate.h loc=L1 community=23]
NODE +relaunch [src=Application/Dopamine/App Delegates/DOSceneDelegate.h loc=L14 community=152]
NODE libjailbreak/src/main.c [src=BaseBin/libjailbreak/src/main.c loc=L1 community=15]
NODE main() [src=BaseBin/ChOma/tests/dsc_tester/main.c loc=L13 community=46]
NODE BaseBin/ChOma/tests/dsc_tester/main.c [src=BaseBin/ChOma/tests/dsc_tester/main.c loc=L1 community=10]
NODE main() [src=BaseBin/ChOma/tests/fat_create/main.c loc=L66 community=43]
NODE get_input_paths() [src=BaseBin/ChOma/tests/fat_create/main.c loc=L48 community=43]
NODE BaseBin/ChOma/tests/fat_create/main.c [src=BaseBin/ChOma/tests/fat_create/main.c loc=L1 community=10]
NODE get_argument_value() [src=BaseBin/ChOma/tests/fat_create/main.c loc=L16 community=43]
NODE argument_exists() [src=BaseBin/ChOma/tests/fat_create/main.c loc=L28 community=43]
NODE print_usage() [src=BaseBin/ChOma/tests/fat_create/main.c loc=L38 community=43]
NODE main() [src=BaseBin/XPF/external/ChOma/tests/dsc_tester/main.c loc=L13 community=37]
NODE external/ChOma/tests/dsc_tester/main.c [src=BaseBin/XPF/external/ChOma/tests/dsc_tester/main.c loc=L1 community=10]
NODE main() [src=BaseBin/XPF/external/ChOma/tests/fat_create/main.c loc=L66 community=17]
NODE get_input_paths() [src=BaseBin/XPF/external/ChOma/tests/fat_create/main.c loc=L48 community=17]
NODE external/ChOma/tests/fat_create/main.c [src=BaseBin/XPF/external/ChOma/tests/fat_create/main.c loc=L1 community=10]
NODE get_argument_value() [src=BaseBin/XPF/external/ChOma/tests/fat_create/main.c loc=L16 community=17]
NODE argument_exists() [src=BaseBin/XPF/external/ChOma/tests/fat_create/main.c loc=L28 community=17]
NODE print_usage() [src=BaseBin/XPF/external/ChOma/tests/fat_create/main.c loc=L38 community=17]
NODE main() [src=BaseBin/_external/modules/litehook/Tests/main.c loc=L53 community=16]
NODE Tests/main.c [src=BaseBin/_external/modules/litehook/Tests/main.c loc=L1 community=16]
NODE test_rebind() [src=BaseBin/_external/modules/litehook/Tests/main.c loc=L23 community=16]
NODE test_symbol_finder() [src=BaseBin/_external/modules/litehook/Tests/main.c loc=L35 community=16]
NODE bind_hook() [src=BaseBin/_external/modules/litehook/Tests/main.c loc=L18 community=16]
NODE test_function() [src=BaseBin/_external/modules/litehook/Tests/main.c loc=L10 community=16]
NODE _ANEDaemonConnection [src=Application/Dopamine/Exploits/weightBufs/exploit/AppleNeuralEngine/_ANEDaemonConnection.h loc=L13 community=106]
NODE _ANEDaemonConnection.h [src=Application/Dopamine/Exploits/weightBufs/exploit/AppleNeuralEngine/_ANEDaemonConnection.h loc=L1 community=214]
NODE +daemonConnection [src=Application/Dopamine/Exploits/weightBufs/exploit/AppleNeuralEngine/_ANEDaemonConnection.h loc=L22 community=106]
NODE +daemonConnectionRestricted [src=Application/Dopamine/Exploits/weightBufs/exploit/AppleNeuralEngine/_ANEDaemonConnection.h loc=L23 community=106]
NODE -beginRealTimeTaskWithReply [src=Application/Dopamine/Exploits/weightBufs/exploit/AppleNeuralEngine/_ANEDaemonConnection.h loc=L29 community=106]
NODE -compiledModelExistsForwithReply [src=Application/Dopamine/Exploits/weightBufs/exploit/AppleNeuralEngine/_ANEDaemonConnection.h loc=L35 community=106]
NODE -compileModelsandboxExtensionoptionsqoswithReply [src=Application/Dopamine/Exploits/weightBufs/exploit/AppleNeuralEngine/_ANEDaemonConnection.h loc=L32 community=106]
NODE -dealloc [src=Application/Dopamine/Exploits/weightBufs/exploit/AppleNeuralEngine/_ANEDaemonConnection.h loc=L24 community=106]
NODE -echowithReply [src=Application/Dopamine/Exploits/weightBufs/exploit/AppleNeuralEngine/_ANEDaemonConnection.h loc=L31 community=106]
NODE -endRealTimeTaskWithReply [src=Application/Dopamine/Exploits/weightBufs/exploit/AppleNeuralEngine/_ANEDaemonConnection.h loc=L30 community=106]
NODE -init [src=Application/Dopamine/Exploits/weightBufs/exploit/AppleNeuralEngine/_ANEDaemonConnection.h loc=L26 community=106]
NODE -initWithMachServiceNamerestricted [src=Application/Dopamine/Exploits/weightBufs/exploit/AppleNeuralEngine/_ANEDaemonConnection.h loc=L28 community=106]
NODE -loadModelsandboxExtensionoptionsqoswithReply [src=Application/Dopamine/Exploits/weightBufs/exploit/AppleNeuralEngine/_ANEDaemonConnection.h loc=L33 community=106]
NODE -purgeCompiledModelwithReply [src=Application/Dopamine/Exploits/weightBufs/exploit/AppleNeuralEngine/_ANEDaemonConnection.h loc=L36 community=106]
NODE -restricted [src=Application/Dopamine/Exploits/weightBufs/exploit/AppleNeuralEngine/_ANEDaemonConnection.h loc=L25 community=106]
NODE -unloadModeloptionsqoswithReply [src=Application/Dopamine/Exploits/weightBufs/exploit/AppleNeuralEngine/_ANEDaemonConnection.h loc=L34 community=106]
NODE -refreshJailbreakAppsPressed [src=Application/Dopamine/UI/Settings/DOSettingsController.m loc=L664 community=35]
NODE -removeJailbreakPressed [src=Application/Dopamine/UI/Settings/DOSettingsController.m loc=L737 community=35]
NODE -viewWillAppear [src=Application/Dopamine/UI/Settings/DOSettingsController.m loc=L36 community=35]
NODE -readAppJITEnabled [src=Application/Dopamine/UI/Settings/DOSettingsController.m loc=L505 community=35]
NODE -setAppJITEnabledspecifier [src=Application/Dopamine/UI/Settings/DOSettingsController.m loc=L515 community=35]
NODE DOSettingsController.m [src=Application/Dopamine/UI/Settings/DOSettingsController.m loc=L1 community=23]
NODE -specifiers [src=Application/Dopamine/UI/Settings/DOSettingsController.m loc=L152 community=8]
NODE -readPreferenceValue [src=Application/Dopamine/UI/Settings/DOSettingsController.m loc=L424 community=35]
NODE -setPreferenceValuespecifier [src=Application/Dopamine/UI/Settings/DOSettingsController.m loc=L418 community=35]
NODE -changeMobilePassword [src=Application/Dopamine/UI/Settings/DOSettingsController.m loc=L696 community=35]
NODE -setBootlogoEnabledspecifier [src=Application/Dopamine/UI/Settings/DOSettingsController.m loc=L559 community=35]
NODE -setCustomBootlogoEnabledspecifier [src=Application/Dopamine/UI/Settings/DOSettingsController.m loc=L588 community=35]
NODE -imagePickerControllerdidFinishPickingMediaWithInfo [src=Application/Dopamine/UI/Settings/DOSettingsController.m loc=L634 community=35]
NODE -readDyldPatchEnabled [src=Application/Dopamine/UI/Settings/DOSettingsController.m loc=L768 community=35]
NODE -readIDownloadEnabled [src=Application/Dopamine/UI/Settings/DOSettingsController.m loc=L460 community=35]
NODE -readJetsamMultiplier [src=Application/Dopamine/UI/Settings/DOSettingsController.m loc=L524 community=35]
NODE -readTweakInjectionEnabled [src=Application/Dopamine/UI/Settings/DOSettingsController.m loc=L478 community=35]
NODE -setDyldPatchEnabledspecifier [src=Application/Dopamine/UI/Settings/DOSettingsController.m loc=L777 community=35]
NODE -setIDownloadEnabledspecifier [src=Application/Dopamine/UI/Settings/DOSettingsController.m loc=L469 community=35]
NODE -setJetsamMultiplierspecifier [src=Application/Dopamine/UI/Settings/DOSettingsController.m loc=L534 community=35]
NODE -setTweakInjectionEnabledspecifier [src=Application/Dopamine/UI/Settings/DOSettingsController.m loc=L487 community=35]
NODE -availablePACBypassIdentifiers [src=Application/Dopamine/UI/Settings/DOSettingsController.m loc=L74 community=35]
NODE -availablePACBypassNames [src=Application/Dopamine/UI/Settings/DOSettingsController.m loc=L86 community=35]
NODE platform_stage_jailbreak_update() [src=BaseBin/launchdhook/src/jbserver/jbdomain_platform.c loc=L31 community=2]
... (truncated — 1614 more nodes cut by ~5000-token budget. Narrow with context_filter=['call'] or use get_node for a specific symbol)
```

## Q2

**Question:** How does DOJailbreaker select and initialize kernel, PAC, and PPL exploit components, and where do XPF patch findings enter?

**Exit code:** 0

```text
Graph: Dopamine-roothide-reconstruction-9617d75f-20261124T024805Z/evidence/source/graphify/graph.json (6291 nodes) | Traversal: BFS depth=3 | Start: ['DOJailbreaker', 'xpf_find_ppl_enter()', 'xpf_find_ppl_dispatch_func()', '+initialize', 'kernel', 'xpf', '-selectedPACBypass', 'pac.h', 'exploit.c', 'ppl.c', 'patchKind', 'string_enumerate_components()', 'xpf_find_pmap_enter_pv()'] | 1469 nodes found

[!] TRUNCATED: showing 163 of 1469 nodes (~5000-token budget). The answer may be among the 1306 cut nodes — raise the token budget to 45002 to get all 1469 (CLI: --budget 45002, MCP: token_budget=45002) or narrow the query (e.g. context_filter=['call'], or get_node for a specific symbol).

NODE DOJailbreaker [src=Application/Dopamine/Jailbreak/DOJailbreaker.h loc=L14 community=71]
NODE xpf_find_ppl_enter() [src=BaseBin/XPF/src/ppl.c loc=L35 community=78]
NODE xpf_find_ppl_dispatch_func() [src=BaseBin/XPF/src/ppl.c loc=L89 community=33]
NODE ppl.c [src=BaseBin/XPF/src/ppl.c loc=L1 community=33]
NODE exploit.c [src=Application/Dopamine/Exploits/multicast_bytecopy/exploit/exploit.c loc=L1 community=13]
NODE -selectedPACBypass [src=Application/Dopamine/Jailbreak/DOExploitManager.m loc=L131 community=81]
NODE xpf_find_pmap_enter_pv() [src=BaseBin/XPF/src/sptm_txm.c loc=L236 community=19]
NODE kernel [src= loc= community=22]
NODE xpf [src= loc= community=22]
NODE +initialize [src=Application/Dopamine/Exploits/weightBufs/exploit/AppleNeuralEngine/_ANEClient.h loc=L21 community=69]
NODE string_enumerate_components() [src=BaseBin/systemhook/src/common/common.c loc=L53 community=123]
NODE pac.h [src=BaseBin/opainject/private/include/pac.h loc=L1 community=268]
NODE patchKind [src=BaseBin/ChOma/src/CachePatching.h loc=L103 community=295]
NODE DOJailbreaker.h [src=Application/Dopamine/Jailbreak/DOJailbreaker.h loc=L1 community=62]
NODE -applyContiguousMappingWorkaround [src=Application/Dopamine/Jailbreak/DOJailbreaker.h loc=L23 community=71]
NODE -runWithErrordidRemoveJailbreakshowLogs [src=Application/Dopamine/Jailbreak/DOJailbreaker.h loc=L19 community=71]
NODE -contiguousMappingWorkaroundNeeded [src=Application/Dopamine/Jailbreak/DOJailbreaker.h loc=L22 community=71]
NODE -finalize [src=Application/Dopamine/Jailbreak/DOJailbreaker.h loc=L20 community=71]
NODE DOJailbreaker [src=BaseBin/dopamine/src/main.m loc=L48 community=225]
NODE -applyProtection [src=BaseBin/dopamine/src/main.m loc=L54 community=225]
NODE xpf_find_ppl_bootstrap_dispatch() [src=BaseBin/XPF/src/ppl.c loc=L44 community=39]
NODE xpf_find_ppl_dispatch_section() [src=BaseBin/XPF/src/ppl.c loc=L6 community=33]
NODE xpf_find_pmap_enter_options_addr() [src=BaseBin/XPF/src/ppl.c loc=L259 community=19]
NODE xpf_find_pmap_enter_pv() [src=BaseBin/XPF/src/ppl.c loc=L222 community=19]
NODE xpf_find_pmap_pin_kernel_pages_reference() [src=BaseBin/XPF/src/ppl.c loc=L194 community=33]
NODE xpf_find_pmap_pin_kernel_pages() [src=BaseBin/XPF/src/ppl.c loc=L171 community=19]
NODE xpf_find_ppl_trust_cache_rt() [src=BaseBin/XPF/src/ppl.c loc=L154 community=33]
NODE xpf_find_ppl_handler_table() [src=BaseBin/XPF/src/ppl.c loc=L70 community=33]
NODE xpf_find_ppl_routine() [src=BaseBin/XPF/src/ppl.c loc=L82 community=33]
NODE xpf_ppl_init() [src=BaseBin/XPF/src/ppl.c loc=L300 community=28]
NODE xpf_find_pmap_remove_options() [src=BaseBin/XPF/src/ppl.c loc=L281 community=19]
NODE xpf_find_pmap_image4_trust_caches() [src=BaseBin/XPF/src/ppl.c loc=L100 community=33]
NODE xpf_find_pmap_query_trust_cache_safe() [src=BaseBin/XPF/src/ppl.c loc=L136 community=78]
NODE xpf_find_pv_head_table() [src=BaseBin/XPF/src/ppl.c loc=L246 community=33]
NODE kernel_patchfinder.c [src=Application/Dopamine/Exploits/Titan/exploit/kernel_patchfinder.c loc=L1 community=34]
NODE kpf_find_get_kernel_data() [src=Application/Dopamine/Exploits/Titan/exploit/kernel_patchfinder.c loc=L363 community=34]
NODE kpf_find_process_kernel_command() [src=Application/Dopamine/Exploits/Titan/exploit/kernel_patchfinder.c loc=L212 community=34]
NODE kpf_fileset_entry_patchfind_text() [src=Application/Dopamine/Exploits/Titan/exploit/kernel_patchfinder.c loc=L110 community=34]
NODE kpf_find_alloc_handles() [src=Application/Dopamine/Exploits/Titan/exploit/kernel_patchfinder.c loc=L338 community=34]
NODE kpf_find_create_shmem() [src=Application/Dopamine/Exploits/Titan/exploit/kernel_patchfinder.c loc=L296 community=34]
NODE kpf_find_delete_command_queue() [src=Application/Dopamine/Exploits/Titan/exploit/kernel_patchfinder.c loc=L162 community=34]
NODE kpf_find_fence_offsets() [src=Application/Dopamine/Exploits/Titan/exploit/kernel_patchfinder.c loc=L239 community=34]
NODE kpf_find_free_gpu_va() [src=Application/Dopamine/Exploits/Titan/exploit/kernel_patchfinder.c loc=L185 community=34]
NODE kpf_find_userclient_vtable() [src=Application/Dopamine/Exploits/Titan/exploit/kernel_patchfinder.c loc=L401 community=34]
NODE kpf_find_wire_range() [src=Application/Dopamine/Exploits/Titan/exploit/kernel_patchfinder.c loc=L382 community=34]
NODE exploit_get_krw_and_kernel_base() [src=Application/Dopamine/Exploits/multicast_bytecopy/exploit/exploit.c loc=L288 community=213]
NODE exploitation_get_krw_with_arb_free() [src=Application/Dopamine/Exploits/multicast_bytecopy/exploit/exploit.c loc=L193 community=97]
NODE exploitation_init() [src=Application/Dopamine/Exploits/multicast_bytecopy/exploit/exploit.c loc=L129 community=105]
NODE exploit_go() [src=Application/Dopamine/Exploits/multicast_bytecopy/exploit/exploit.c loc=L309 community=213]
NODE exploitation_cleanup() [src=Application/Dopamine/Exploits/multicast_bytecopy/exploit/exploit.c loc=L275 community=97]
NODE get_arb_free_holder() [src=Application/Dopamine/Exploits/multicast_bytecopy/exploit/exploit.c loc=L39 community=213]
NODE xpf_find_pmap_enter_options_addr() [src=BaseBin/XPF/src/non_ppl.c loc=L143 community=19]
NODE xpf_non_ppl_init() [src=BaseBin/XPF/src/non_ppl.c loc=L211 community=28]
NODE non_ppl.c [src=BaseBin/XPF/src/non_ppl.c loc=L1 community=19]
NODE xpf_find_trust_cache_rt() [src=BaseBin/XPF/src/non_ppl.c loc=L45 community=19]
NODE xpf_find_pmap_image4_trust_caches() [src=BaseBin/XPF/src/non_ppl.c loc=L4 community=19]
NODE xpf_find_pmap_remove_options() [src=BaseBin/XPF/src/non_ppl.c loc=L176 community=19]
NODE xpf_find_pmap_tt_deallocate() [src=BaseBin/XPF/src/non_ppl.c loc=L80 community=19]
NODE xpf_find_pmap_tt_deallocate_reference() [src=BaseBin/XPF/src/non_ppl.c loc=L113 community=33]
NODE xpf_find_pp_attr_table() [src=BaseBin/XPF/src/non_ppl.c loc=L206 community=19]
NODE xpf_find_vm_last_phys() [src=BaseBin/XPF/src/non_ppl.c loc=L201 community=19]
NODE -selectedKernelExploit [src=Application/Dopamine/Jailbreak/DOExploitManager.m loc=L122 community=81]
NODE -selectedPPLBypass [src=Application/Dopamine/Jailbreak/DOExploitManager.m loc=L140 community=81]
NODE -preferredKernelExploit [src=Application/Dopamine/Jailbreak/DOExploitManager.m loc=L106 community=81]
NODE -preferredPACBypass [src=Application/Dopamine/Jailbreak/DOExploitManager.m loc=L111 community=81]
NODE -availableExploitIdentifiersForType [src=Application/Dopamine/Jailbreak/DOExploitManager.m loc=L96 community=81]
NODE -_findExploitWithIdentifierandType [src=Application/Dopamine/Jailbreak/DOExploitManager.m loc=L48 community=81]
NODE -_loadAvailableExploits [src=Application/Dopamine/Jailbreak/DOExploitManager.m loc=L56 community=81]
NODE DOExploitManager.m [src=Application/Dopamine/Jailbreak/DOExploitManager.m loc=L1 community=32]
NODE -_findPreferredExploitForType [src=Application/Dopamine/Jailbreak/DOExploitManager.m loc=L37 community=81]
NODE -preferredPPLBypass [src=Application/Dopamine/Jailbreak/DOExploitManager.m loc=L117 community=81]
NODE -init [src=Application/Dopamine/Jailbreak/DOExploitManager.m loc=L27 community=81]
NODE xpf_find_papt_ranges_compressed_n_papt_ranges_compressed() [src=BaseBin/XPF/src/sptm_txm.c loc=L675 community=33]
NODE xpf_find_sptm_args() [src=BaseBin/XPF/src/sptm_txm.c loc=L6 community=19]
NODE xpf_find_pv_head_table() [src=BaseBin/XPF/src/sptm_txm.c loc=L358 community=33]
NODE xpf_find_sptm_frame_type_descriptor_size() [src=BaseBin/XPF/src/sptm_txm.c loc=L125 community=33]
NODE xpf_find_pv_alloc() [src=BaseBin/XPF/src/sptm_txm.c loc=L300 community=19]
NODE xpf_find_vm_page_find_canonical_radix() [src=BaseBin/XPF/src/sptm_txm.c loc=L782 community=39]
NODE xpf_find_cpu_ttep() [src=BaseBin/XPF/src/sptm_txm.c loc=L496 community=33]
NODE xpf_find_libsptm_init() [src=BaseBin/XPF/src/sptm_txm.c loc=L426 community=78]
NODE xpf_find_sptm_get_page_table_refcnt() [src=BaseBin/XPF/src/sptm_txm.c loc=L44 community=19]
NODE xpf_find_txm_trustcache_root() [src=BaseBin/XPF/src/sptm_txm.c loc=L543 community=19]
NODE xpf_find_libsptm_frame_table() [src=BaseBin/XPF/src/sptm_txm.c loc=L183 community=33]
NODE xpf_find_txm_developer_mode_storage() [src=BaseBin/XPF/src/sptm_txm.c loc=L589 community=19]
NODE xpf_find_libsptm_init_str_reference() [src=BaseBin/XPF/src/sptm_txm.c loc=L468 community=33]
NODE xpf_find_libsptm_frame_type_params() [src=BaseBin/XPF/src/sptm_txm.c loc=L105 community=33]
NODE xpf_find_papt_ranges_update() [src=BaseBin/XPF/src/sptm_txm.c loc=L653 community=19]
NODE xpf_find_pmap_tte_deallocate() [src=BaseBin/XPF/src/sptm_txm.c loc=L760 community=19]
NODE xpf_find_pp_attr_table() [src=BaseBin/XPF/src/sptm_txm.c loc=L281 community=33]
NODE xpf_find_sptm_get_page_table_refcnt_references() [src=BaseBin/XPF/src/sptm_txm.c loc=L83 community=33]
NODE xpf_find_txm_deviceTreeTrustCacheRange() [src=BaseBin/XPF/src/sptm_txm.c loc=L521 community=19]
NODE xpf_find_wfe_timeout_configure() [src=BaseBin/XPF/src/sptm_txm.c loc=L407 community=19]
NODE xpf_find_vm_page_find_canonical_radix_ref() [src=BaseBin/XPF/src/sptm_txm.c loc=L817 community=33]
NODE xpf_sptm_txm_init() [src=BaseBin/XPF/src/sptm_txm.c loc=L835 community=28]
NODE xpf_find_n_papt_ranges_compressed() [src=BaseBin/XPF/src/sptm_txm.c loc=L746 community=33]
NODE xpf_find_papt_ranges_compressed() [src=BaseBin/XPF/src/sptm_txm.c loc=L753 community=33]
NODE sptm_txm.c [src=BaseBin/XPF/src/sptm_txm.c loc=L1 community=33]
NODE xpf_start_with_kernel_path() [src=BaseBin/XPF/src/xpf.c loc=L480 community=28]
NODE xpf_item_resolve() [src=BaseBin/XPF/src/xpf.c loc=L697 community=33]
NODE xpf.c [src=BaseBin/XPF/src/xpf.c loc=L1 community=28]
NODE xpf_offset_dictionary_add_set() [src=BaseBin/XPF/src/xpf.c loc=L753 community=28]
NODE xpf_item_register() [src=BaseBin/XPF/src/xpf.c loc=L673 community=28]
NODE xpf_print_all_items() [src=BaseBin/XPF/src/xpf.c loc=L713 community=28]
NODE xpf_construct_offset_dictionary() [src=BaseBin/XPF/src/xpf.c loc=L783 community=28]
NODE xpf_pfsec_init() [src=BaseBin/XPF/src/xpf.c loc=L428 community=27]
NODE xpf_set_error() [src=BaseBin/XPF/src/xpf.c loc=L820 community=28]
NODE xpf_sptm_pfsec_init() [src=BaseBin/XPF/src/xpf.c loc=L438 community=27]
NODE xpf_txm_pfsec_init() [src=BaseBin/XPF/src/xpf.c loc=L450 community=27]
NODE xpf_find_set() [src=BaseBin/XPF/src/xpf.c loc=L732 community=28]
NODE xpf_load_img4() [src=BaseBin/XPF/src/xpf.c loc=L462 community=28]
NODE xpf_stop() [src=BaseBin/XPF/src/xpf.c loc=L839 community=28]
NODE xpf_supported_16down() [src=BaseBin/XPF/src/xpf.c loc=L83 community=28]
NODE xpf_arm64_kcall_supported() [src=BaseBin/XPF/src/xpf.c loc=L109 community=28]
NODE xpf_get_error() [src=BaseBin/XPF/src/xpf.c loc=L834 community=28]
NODE xpf_set_is_supported() [src=BaseBin/XPF/src/xpf.c loc=L747 community=28]
NODE xpf_supported_1516() [src=BaseBin/XPF/src/xpf.c loc=L89 community=28]
NODE xpf_supported_15up() [src=BaseBin/XPF/src/xpf.c loc=L65 community=28]
NODE xpf_supported_16up() [src=BaseBin/XPF/src/xpf.c loc=L77 community=28]
NODE xpf_supported_16up_no_sptm() [src=BaseBin/XPF/src/xpf.c loc=L99 community=28]
NODE xpf_supported_16up_sptm() [src=BaseBin/XPF/src/xpf.c loc=L94 community=28]
NODE xpf_supported_non_sptm() [src=BaseBin/XPF/src/xpf.c loc=L59 community=28]
NODE xpf_supported_sptm() [src=BaseBin/XPF/src/xpf.c loc=L23 community=28]
NODE xpf_trigon_supported() [src=BaseBin/XPF/src/xpf.c loc=L114 community=28]
NODE xpfsec_decode_pointer() [src=BaseBin/XPF/src/xpf.c loc=L722 community=27]
NODE xpf_supported_arm64() [src=BaseBin/XPF/src/xpf.c loc=L104 community=28]
NODE xpf_set_ignore_base_set() [src=BaseBin/XPF/src/xpf.c loc=L778 community=28]
NODE xpf_supported_15down() [src=BaseBin/XPF/src/xpf.c loc=L71 community=28]
NODE xpf_supported_18_down_incl_26b1() [src=BaseBin/XPF/src/xpf.c loc=L38 community=28]
NODE xpf_supported_26_up_excl_26b1() [src=BaseBin/XPF/src/xpf.c loc=L46 community=28]
NODE xpf_supported_always() [src=BaseBin/XPF/src/xpf.c loc=L18 community=28]
NODE xpf_supported_sptm_18_3_down() [src=BaseBin/XPF/src/xpf.c loc=L28 community=28]
NODE xpf_supported_sptm_18_4_to_26_x() [src=BaseBin/XPF/src/xpf.c loc=L33 community=28]
NODE xpf_supported_sptm_27_0_up() [src=BaseBin/XPF/src/xpf.c loc=L54 community=28]
NODE xpf_find_pacda_gadget() [src=BaseBin/XPF/src/bad_recovery.c loc=L193 community=148]
NODE xpf_find_thread_machine_kstackptr() [src=BaseBin/XPF/src/bad_recovery.c loc=L246 community=148]
NODE xpf_find_hw_lck_ticket_reserve_orig_allow_invalid_signed() [src=BaseBin/XPF/src/bad_recovery.c loc=L28 community=148]
NODE xpf_find_br_x22_gadget() [src=BaseBin/XPF/src/bad_recovery.c loc=L70 community=148]
NODE xpf_find_exception_return_after_check() [src=BaseBin/XPF/src/bad_recovery.c loc=L96 community=148]
NODE xpf_find_exception_return_after_check_no_restore() [src=BaseBin/XPF/src/bad_recovery.c loc=L117 community=148]
NODE xpf_find_str_x0_x19_ldr_x20_gadget() [src=BaseBin/XPF/src/bad_recovery.c loc=L169 community=148]
NODE xpf_find_hw_lck_ticket_reserve_orig_allow_invalid() [src=BaseBin/XPF/src/bad_recovery.c loc=L60 community=148]
NODE xpf_find_ldp_x0_x1_x8_gadget() [src=BaseBin/XPF/src/bad_recovery.c loc=L135 community=148]
NODE xpf_find_ml_sign_thread_state() [src=BaseBin/XPF/src/bad_recovery.c loc=L213 community=148]
NODE xpf_find_str_x8_x9_gadget() [src=BaseBin/XPF/src/bad_recovery.c loc=L152 community=148]
NODE xpf_bad_recovery_init() [src=BaseBin/XPF/src/bad_recovery.c loc=L296 community=28]
NODE bad_recovery.c [src=BaseBin/XPF/src/bad_recovery.c loc=L1 community=148]
NODE xpf_find_task_itk_space() [src=BaseBin/XPF/src/common.c loc=L518 community=33]
NODE xpf_find_proc_apply_sandbox() [src=BaseBin/XPF/src/common.c loc=L943 community=19]
NODE xpf_find_proc_struct_size() [src=BaseBin/XPF/src/common.c loc=L742 community=33]
NODE xpf_find_vm_reference() [src=BaseBin/XPF/src/common.c loc=L620 community=19]
NODE xpf_find_allproc() [src=BaseBin/XPF/src/common.c loc=L355 community=19]
NODE xpf_find_developer_mode_enabled() [src=BaseBin/XPF/src/common.c loc=L1113 community=19]
NODE xpf_find_vm_map_pmap() [src=BaseBin/XPF/src/common.c loc=L691 community=19]
NODE xpf_find_proc_get_syscall_filter_mask_size() [src=BaseBin/XPF/src/common.c loc=L982 community=19]
NODE xpf_find_IOSurface_rangeCount() [src=BaseBin/XPF/src/common.c loc=L1501 community=33]
NODE xpf_find_IOSurface_ranges() [src=BaseBin/XPF/src/common.c loc=L1464 community=19]
NODE xpf_find_PT_INDEX_MAX() [src=BaseBin/XPF/src/common.c loc=L129 community=19]
NODE xpf_find_task_security_config() [src=BaseBin/XPF/src/common.c loc=L1559 community=19]
NODE xpf_find_kfree_data_external() [src=BaseBin/XPF/src/common.c loc=L323 community=78]
NODE xpf_find_task_collect_crash_info() [src=BaseBin/XPF/src/common.c loc=L469 community=19]
NODE xpf_find_task_crashinfo_release_ref() [src=BaseBin/XPF/src/common.c loc=L419 community=19]
NODE xpf_find_thread_machine_CpuDatap() [src=BaseBin/XPF/src/common.c loc=L1260 community=19]
NODE xpf_find_thread_machine_kstackptr() [src=BaseBin/XPF/src/common.c loc=L1321 community=19]
... (truncated — 1306 more nodes cut by ~5000-token budget. Narrow with context_filter=['call'] or use get_node for a specific symbol)
```

## Q3

**Question:** How do privilege elevation, fake root setup, bootstrap, trust cache, launchdhook Mach port handoff, and cleanup connect?

**Exit code:** 0

```text
Graph: Dopamine-roothide-reconstruction-9617d75f-20261124T024805Z/evidence/source/graphify/graph.json (6291 nodes) | Traversal: BFS depth=3 | Start: ['root_trustcache_info()', 'root_trustcache_clear()', 'launchdhook/src/crashreporter.h', '-setup', '-cleanup', 'port', 'mach', 'fakelib_redirect.c', 'launchdhook/src/main.m', 'connection.h', 'BootstrapErrorCode', 'trustcache.c', 'roothider_main.c', 'cacheType', 'physrw_pte_handoff()', '-elevatePrivileges'] | 2467 nodes found

[!] TRUNCATED: showing 156 of 2467 nodes (~5000-token budget). The answer may be among the 2311 cut nodes — raise the token budget to 75087 to get all 2467 (CLI: --budget 75087, MCP: token_budget=75087) or narrow the query (e.g. context_filter=['call'], or get_node for a specific symbol).

NODE root_trustcache_info() [src=BaseBin/launchdhook/src/jbserver/jbdomain_root.c loc=L84 community=58]
NODE root_trustcache_clear() [src=BaseBin/launchdhook/src/jbserver/jbdomain_root.c loc=L98 community=58]
NODE launchdhook/src/crashreporter.h [src=BaseBin/launchdhook/src/crashreporter.h loc=L1 community=2]
NODE port [src=Application/Dopamine/Exploits/kfd/Exploit/libkfd/krkw/IOSurface_shared.h loc=L128 community=287]
NODE trustcache.c [src=BaseBin/libjailbreak/src/trustcache.c loc=L1 community=52]
NODE BootstrapErrorCode [src=Application/Dopamine/Jailbreak/DOBootstrapper.h loc=L13 community=217]
NODE physrw_pte_handoff() [src=BaseBin/libjailbreak/src/physrw_pte.c loc=L150 community=15]
NODE -elevatePrivileges [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L253 community=71]
NODE fakelib_redirect.c [src=BaseBin/dyldhook/src/fakelib_redirect.c loc=L1 community=31]
NODE launchdhook/src/main.m [src=BaseBin/launchdhook/src/main.m loc=L1 community=2]
NODE roothider_main.c [src=BaseBin/systemhook/src/roothider_main.c loc=L1 community=11]
NODE -cleanup [src=Application/Dopamine/Jailbreak/DOExploit.h loc=L44 community=81]
NODE -setup [src=Application/Dopamine/UI/Update/DOUpdateCircleView.m loc=L28 community=88]
NODE connection.h [src=BaseBin/_external/include/xpc/connection.h loc=L1 community=62]
NODE mach [src= loc= community=13]
NODE cacheType [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L47 community=4]
NODE jbdomain_root.c [src=BaseBin/launchdhook/src/jbserver/jbdomain_root.c loc=L1 community=58]
NODE root_steal_ucred() [src=BaseBin/launchdhook/src/jbserver/jbdomain_root.c loc=L35 community=58]
NODE root_set_mac_label() [src=BaseBin/launchdhook/src/jbserver/jbdomain_root.c loc=L66 community=58]
NODE root_sign_thread() [src=BaseBin/launchdhook/src/jbserver/jbdomain_root.c loc=L25 community=58]
NODE root_get_physrw() [src=BaseBin/launchdhook/src/jbserver/jbdomain_root.c loc=L20 community=58]
NODE root_get_sysinfo() [src=BaseBin/launchdhook/src/jbserver/jbdomain_root.c loc=L30 community=96]
NODE root_domain_allowed() [src=BaseBin/launchdhook/src/jbserver/jbdomain_root.c loc=L15 community=58]
NODE crash_reporter_state [src=BaseBin/launchdhook/src/crashreporter.h loc=L37 community=314]
NODE kCrashReporterStateActive [src=BaseBin/launchdhook/src/crashreporter.h loc=L39 community=314]
NODE kCrashReporterStateNotActive [src=BaseBin/launchdhook/src/crashreporter.h loc=L38 community=314]
NODE kCrashReporterStatePaused [src=BaseBin/launchdhook/src/crashreporter.h loc=L40 community=314]
NODE launchdhook/src/crashreporter.m [src=BaseBin/launchdhook/src/crashreporter.m loc=L1 community=32]
NODE roothide_trust_executable_recurse() [src=BaseBin/launchdhook/src/jbserver/jbdomain_roothide.c loc=L57 community=135]
NODE roothide_trust_library_recurse() [src=BaseBin/launchdhook/src/jbserver/jbdomain_roothide.c loc=L62 community=135]
NODE trust_macho_recurse() [src=BaseBin/launchdhook/src/jbserver/jbdomain_roothide.c loc=L27 community=135]
NODE roothide_get_alternative_port() [src=BaseBin/launchdhook/src/jbserver/jbdomain_roothide.c loc=L184 community=135]
NODE roothide_unsupport_request() [src=BaseBin/launchdhook/src/jbserver/jbdomain_roothide.c loc=L8 community=135]
NODE jbdomain_roothide.c [src=BaseBin/launchdhook/src/jbserver/jbdomain_roothide.c loc=L1 community=135]
NODE roothide_jailbreakd_checkin() [src=BaseBin/launchdhook/src/jbserver/jbdomain_roothide.c loc=L136 community=135]
NODE roothide_blacklist_check() [src=BaseBin/launchdhook/src/jbserver/jbdomain_roothide.c loc=L100 community=135]
NODE roothide_jailbreakd_lookup() [src=BaseBin/launchdhook/src/jbserver/jbdomain_roothide.c loc=L130 community=135]
NODE roothide_domain_allowed() [src=BaseBin/launchdhook/src/jbserver/jbdomain_roothide.c loc=L14 community=135]
NODE roothide_dyld_patch_enabled() [src=BaseBin/launchdhook/src/jbserver/jbdomain_roothide.c loc=L149 community=135]
NODE roothide_jailbroken_check() [src=BaseBin/launchdhook/src/jbserver/jbdomain_roothide.c loc=L71 community=135]
NODE roothide_palehide_present() [src=BaseBin/launchdhook/src/jbserver/jbdomain_roothide.c loc=L77 community=135]
NODE roothide_set_dyld_patch() [src=BaseBin/launchdhook/src/jbserver/jbdomain_roothide.c loc=L155 community=135]
NODE iokit_get_connection() [src=Application/Dopamine/Exploits/kfd/Exploit/libkfd/krkw/IOSurface_shared.h loc=L132 community=60]
NODE port [src=BaseBin/_external/include/bsm/audit.h loc=L204 community=198]
NODE at_port [src=BaseBin/_external/include/bsm/audit.h loc=L210 community=198]
NODE machine [src=BaseBin/_external/include/bsm/audit.h loc=L205 community=198]
NODE trustcache_file_upload() [src=BaseBin/libjailbreak/src/trustcache.c loc=L328 community=52]
NODE trustcache_contains_cdhash() [src=BaseBin/libjailbreak/src/trustcache.c loc=L450 community=52]
NODE trustcache_list_insert() [src=BaseBin/libjailbreak/src/trustcache.c loc=L61 community=52]
NODE trustcache_list_remove() [src=BaseBin/libjailbreak/src/trustcache.c loc=L92 community=52]
NODE trustcache_file_build_from_cdhashes() [src=BaseBin/libjailbreak/src/trustcache.c loc=L403 community=52]
NODE trustcache_file_upload_with_uuid() [src=BaseBin/libjailbreak/src/trustcache.c loc=L397 community=52]
NODE trustcache_file_build_from_path() [src=BaseBin/libjailbreak/src/trustcache.c loc=L423 community=52]
NODE jb_trustcache_add_cdhashes() [src=BaseBin/libjailbreak/src/trustcache.c loc=L225 community=52]
NODE jb_trustcache_add_entries() [src=BaseBin/libjailbreak/src/trustcache.c loc=L189 community=52]
NODE jb_trustcache_debug_print() [src=BaseBin/libjailbreak/src/trustcache.c loc=L278 community=52]
NODE _jb_trustcache_grow() [src=BaseBin/libjailbreak/src/trustcache.c loc=L168 community=52]
NODE is_cdhash_trustcached() [src=BaseBin/libjailbreak/src/trustcache.c loc=L476 community=52]
NODE _is_jb_trustcache() [src=BaseBin/libjailbreak/src/trustcache.c loc=L139 community=52]
NODE jb_trustcache_info() [src=BaseBin/libjailbreak/src/trustcache.c loc=L252 community=14]
NODE _trustcache_list_get_start() [src=BaseBin/libjailbreak/src/trustcache.c loc=L22 community=52]
NODE _trustcache_list_set_start() [src=BaseBin/libjailbreak/src/trustcache.c loc=L37 community=52]
NODE _trustcache_file_init() [src=BaseBin/libjailbreak/src/trustcache.c loc=L10 community=52]
NODE _trustcache_file_sort() [src=BaseBin/libjailbreak/src/trustcache.c loc=L134 community=52]
NODE jb_trustcache_clear() [src=BaseBin/libjailbreak/src/trustcache.c loc=L161 community=52]
NODE _trustcache_list_enumerate() [src=BaseBin/libjailbreak/src/trustcache.c loc=L50 community=52]
NODE jb_trustcache_add_entry() [src=BaseBin/libjailbreak/src/trustcache.c loc=L236 community=52]
NODE _jb_trustcache_enumerate() [src=BaseBin/libjailbreak/src/trustcache.c loc=L152 community=52]
NODE _trustcache_file_sort_entry_comparator_v1() [src=BaseBin/libjailbreak/src/trustcache.c loc=L127 community=52]
NODE trustcache.h [src=BaseBin/libjailbreak/src/trustcache.h loc=L1 community=13]
NODE trustcache_fs.c [src=BaseBin/libjailbreak/src/trustcache_fs.c loc=L1 community=82]
NODE jb_trustcache_add_directory() [src=BaseBin/libjailbreak/src/trustcache_fs.c loc=L94 community=82]
NODE jb_trustcache_add_file() [src=BaseBin/libjailbreak/src/trustcache_fs.c loc=L80 community=82]
NODE directory_collect_untrusted_cdhashes_by_path() [src=BaseBin/libjailbreak/src/trustcache_fs.c loc=L59 community=82]
NODE walk_machos_in_dir() [src=BaseBin/libjailbreak/src/trustcache_fs.c loc=L12 community=82]
NODE trustcache_fs.h [src=BaseBin/libjailbreak/src/trustcache_fs.h loc=L1 community=82]
NODE trustcache_structs.h [src=BaseBin/libjailbreak/src/trustcache_structs.h loc=L1 community=13]
NODE jbclient_root_trustcache_info() [src=BaseBin/libjailbreak/src/jbclient_xpc.c loc=L465 community=42]
NODE jbclient_root_trustcache_clear() [src=BaseBin/libjailbreak/src/jbclient_xpc.c loc=L494 community=42]
NODE jbclient_trust_file() [src=BaseBin/libjailbreak/src/jbclient_xpc.c loc=L131 community=42]
NODE jbclient_trust_file_by_path() [src=BaseBin/libjailbreak/src/jbclient_xpc.c loc=L149 community=42]
NODE jbclient_root_get_sysinfo() [src=BaseBin/libjailbreak/src/jbclient_xpc.c loc=L421 community=42]
NODE jbclient_root_sign_thread() [src=BaseBin/libjailbreak/src/jbclient_xpc.c loc=L407 community=42]
NODE jbclient_get_jbroot() [src=BaseBin/libjailbreak/src/jbclient_xpc.c loc=L91 community=42]
NODE jbclient_root_get_physrw() [src=BaseBin/libjailbreak/src/jbclient_xpc.c loc=L390 community=42]
NODE jbclient_dopamine_drop_root() [src=BaseBin/libjailbreak/src/jbclient_xpc.c loc=L542 community=42]
NODE jbclient_dopamine_get_root() [src=BaseBin/libjailbreak/src/jbclient_xpc.c loc=L531 community=42]
NODE jbclient_root_set_mac_label() [src=BaseBin/libjailbreak/src/jbclient_xpc.c loc=L449 community=42]
NODE jbclient_root_steal_ucred() [src=BaseBin/libjailbreak/src/jbclient_xpc.c loc=L434 community=42]
NODE jbclient_xpc_set_custom_port() [src=BaseBin/libjailbreak/src/jbclient_xpc.c loc=L32 community=42]
NODE libroothider/src/crashreporter.h [src=BaseBin/libroothider/src/crashreporter.h loc=L1 community=2]
NODE libroothider/src/crashreporter.m [src=BaseBin/libroothider/src/crashreporter.m loc=L1 community=2]
NODE macho_get_containing_cache() [src=BaseBin/ChOma/src/MachO.c loc=L112 community=26]
NODE BaseBin/ChOma/src/MachO.c [src=BaseBin/ChOma/src/MachO.c loc=L1 community=26]
NODE _macho_parse() [src=BaseBin/ChOma/src/MachO.c loc=L703 community=26]
NODE macho_enumerate_load_commands() [src=BaseBin/ChOma/src/MachO.c loc=L205 community=26]
NODE macho_read_at_offset() [src=BaseBin/ChOma/src/MachO.c loc=L14 community=26]
NODE macho_enumerate_symbols() [src=BaseBin/ChOma/src/MachO.c loc=L304 community=26]
NODE macho_init_for_writing() [src=BaseBin/ChOma/src/MachO.c loc=L740 community=26]
NODE macho_free() [src=BaseBin/ChOma/src/MachO.c loc=L807 community=26]
NODE macho_get_stream() [src=BaseBin/ChOma/src/MachO.c loc=L86 community=43]
NODE macho_parse_fileset_machos() [src=BaseBin/ChOma/src/MachO.c loc=L675 community=26]
NODE macho_init() [src=BaseBin/ChOma/src/MachO.c loc=L715 community=26]
NODE macho_read_string_at_offset() [src=BaseBin/ChOma/src/MachO.c loc=L31 community=26]
NODE macho_translate_fileoff_to_vmaddr() [src=BaseBin/ChOma/src/MachO.c loc=L117 community=26]
NODE macho_translate_vmaddr_to_fileoff() [src=BaseBin/ChOma/src/MachO.c loc=L132 community=26]
NODE macho_write_at_offset() [src=BaseBin/ChOma/src/MachO.c loc=L81 community=26]
NODE macho_enumerate_function_starts() [src=BaseBin/ChOma/src/MachO.c loc=L539 community=26]
NODE macho_get_mach_header_size() [src=BaseBin/ChOma/src/MachO.c loc=L101 community=26]
NODE macho_read_at_vmaddr() [src=BaseBin/ChOma/src/MachO.c loc=L148 community=26]
NODE macho_read_trie_node_at_offset() [src=BaseBin/ChOma/src/MachO.c loc=L271 community=26]
NODE macho_enumerate_dependencies() [src=BaseBin/ChOma/src/MachO.c loc=L448 community=26]
NODE macho_get_base_address() [src=BaseBin/ChOma/src/MachO.c loc=L517 community=26]
NODE macho_is_encrypted() [src=BaseBin/ChOma/src/MachO.c loc=L791 community=26]
NODE macho_read_string_at_vmaddr() [src=BaseBin/ChOma/src/MachO.c loc=L169 community=26]
NODE macho_read_uleb128_at_offset() [src=BaseBin/ChOma/src/MachO.c loc=L43 community=26]
NODE macho_write_at_vmaddr() [src=BaseBin/ChOma/src/MachO.c loc=L189 community=26]
NODE macho_array_create_for_paths() [src=BaseBin/ChOma/src/MachO.c loc=L769 community=26]
NODE macho_enumerate_rpaths() [src=BaseBin/ChOma/src/MachO.c loc=L484 community=26]
NODE macho_enumerate_sections() [src=BaseBin/ChOma/src/MachO.c loc=L254 community=26]
NODE macho_enumerate_segments() [src=BaseBin/ChOma/src/MachO.c loc=L244 community=26]
NODE macho_get_filetype() [src=BaseBin/ChOma/src/MachO.c loc=L91 community=26]
NODE macho_get_mach_header_and_commands_size() [src=BaseBin/ChOma/src/MachO.c loc=L106 community=26]
NODE macho_lookup_segment_by_addr() [src=BaseBin/ChOma/src/MachO.c loc=L582 community=26]
NODE macho_parse_segments() [src=BaseBin/ChOma/src/MachO.c loc=L608 community=26]
NODE macho_lookup_section_by_addr() [src=BaseBin/ChOma/src/MachO.c loc=L595 community=26]
NODE macho_get_mach_header() [src=BaseBin/ChOma/src/MachO.c loc=L96 community=26]
NODE macho_get_containing_cache() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L112 community=25]
NODE external/ChOma/src/MachO.c [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L1 community=25]
NODE _macho_parse() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L703 community=25]
NODE macho_enumerate_load_commands() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L205 community=25]
NODE macho_read_at_offset() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L14 community=25]
NODE macho_enumerate_symbols() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L304 community=25]
NODE macho_init_for_writing() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L740 community=25]
NODE macho_free() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L807 community=25]
NODE macho_get_stream() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L86 community=25]
NODE macho_parse_fileset_machos() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L675 community=25]
NODE macho_get_base_address() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L517 community=25]
NODE macho_init() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L715 community=25]
NODE macho_read_string_at_offset() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L31 community=25]
NODE macho_translate_fileoff_to_vmaddr() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L117 community=25]
NODE macho_translate_vmaddr_to_fileoff() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L132 community=25]
NODE macho_write_at_offset() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L81 community=25]
NODE macho_enumerate_function_starts() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L539 community=25]
NODE macho_get_mach_header_size() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L101 community=25]
NODE macho_read_at_vmaddr() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L148 community=25]
NODE macho_read_trie_node_at_offset() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L271 community=25]
NODE macho_enumerate_dependencies() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L448 community=25]
NODE macho_get_filetype() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L91 community=25]
NODE macho_is_encrypted() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L791 community=25]
NODE macho_read_string_at_vmaddr() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L169 community=25]
NODE macho_read_uleb128_at_offset() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L43 community=25]
NODE macho_write_at_vmaddr() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L189 community=25]
NODE macho_array_create_for_paths() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L769 community=17]
NODE macho_enumerate_rpaths() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L484 community=25]
NODE macho_enumerate_sections() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L254 community=25]
... (truncated — 2311 more nodes cut by ~5000-token budget. Narrow with context_filter=['call'] or use get_node for a specific symbol)
```

## Q4

**Question:** How does the BaseBin Makefile build and package basebin.tar, and which targets depend on one another?

**Exit code:** 0

```text
Graph: Dopamine-roothide-reconstruction-9617d75f-20261124T024805Z/evidence/source/graphify/graph.json (6291 nodes) | Traversal: BFS depth=3 | Start: ['dependentsStartArrayIndex', 'build', 'Package.swift', 'BaseBin/ChOma/src/MachO.c', 'target_proc_with_ucred()', '_ANECloneHelper', '+preferenceSpecifierNamedtargetsetgetdetailcelledit'] | 1341 nodes found

[!] TRUNCATED: showing 161 of 1341 nodes (~5000-token budget). The answer may be among the 1180 cut nodes — raise the token budget to 40270 to get all 1341 (CLI: --budget 40270, MCP: token_budget=40270) or narrow the query (e.g. context_filter=['call'], or get_node for a specific symbol).

NODE dependentsStartArrayIndex [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L167 community=234]
NODE build [src=.github/workflows/main.yml loc=L21 community=61]
NODE Package.swift [src=BaseBin/MachOMerger/Package.swift loc=L1 community=333]
NODE +preferenceSpecifierNamedtargetsetgetdetailcelledit [src=Application/Frameworks/Preferences.framework/Headers/PSSpecifier.h loc=L88 community=8]
NODE BaseBin/ChOma/src/MachO.c [src=BaseBin/ChOma/src/MachO.c loc=L1 community=26]
NODE _ANECloneHelper [src=Application/Dopamine/Exploits/weightBufs/exploit/AppleNeuralEngine/_ANECloneHelper.h loc=L10 community=117]
NODE target_proc_with_ucred() [src=BaseBin/libjailbreak/src/util.c loc=L1040 community=14]
NODE BaseBin/ChOma/src/dyld_cache_format.h [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L1 community=110]
NODE reExportsStartArrayIndex [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L168 community=234]
NODE dyld_cache_image_info_extra [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L161 community=234]
NODE exportsTrieAddr [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L163 community=234]
NODE exportsTrieSize [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L165 community=234]
NODE weakBindingsAddr [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L164 community=234]
NODE weakBindingsSize [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L166 community=234]
NODE dyld_cache_header [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L32 community=4]
NODE dyld_cache_accelerator_info [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L172 community=101]
NODE dyld_cache_mapping_and_slide_info [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L136 community=193]
NODE dyld_cache_slide_info2 [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L305 community=194]
NODE dyld_cache_slide_info4 [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L469 community=195]
NODE dyld_cache_local_symbols_info [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L546 community=235]
NODE dyld_cache_slide_info [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L224 community=236]
NODE dyld_cache_image_info [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L152 community=253]
NODE dyld_cache_mapping_info [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L117 community=254]
NODE dyld_cache_slide_info3 [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L369 community=255]
NODE dyld_cache_slide_info5 [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L528 community=256]
NODE dyld_cache_image_text_info [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L213 community=278]
NODE dyld_cache_accelerator_dof [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L206 community=298]
NODE dyld_cache_dynamic_data_header [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L585 community=299]
NODE dyld_cache_local_symbols_entry [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L556 community=300]
NODE dyld_cache_local_symbols_entry_64 [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L563 community=301]
NODE dyld_cache_range_entry [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L199 community=110]
NODE dyld_cache_slide_pointer3 [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L380 community=302]
NODE dyld_cache_slide_pointer5 [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L539 community=303]
NODE dyld_subcache_entry [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L576 community=304]
NODE dyld_cache_accelerator_initializer [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L193 community=110]
NODE dyld_cache_tpro_mapping_info [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L147 community=110]
NODE dyld_subcache_entry_v1 [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L570 community=110]
NODE dyld_cache_slide_info_entry [src=BaseBin/ChOma/src/dyld_cache_format.h loc=L236 community=110]
NODE packages [src=.github/workflows/main.yml loc=L38 community=61]
NODE PackageDescription [src=BaseBin/MachOMerger/Package.swift loc=L4 community=333]
NODE macho_enumerate_dependencies() [src=BaseBin/ChOma/src/MachO.c loc=L448 community=26]
NODE macho_enumerate_function_starts() [src=BaseBin/ChOma/src/MachO.c loc=L539 community=26]
NODE macho_enumerate_load_commands() [src=BaseBin/ChOma/src/MachO.c loc=L205 community=26]
NODE macho_read_at_offset() [src=BaseBin/ChOma/src/MachO.c loc=L14 community=26]
NODE macho_enumerate_symbols() [src=BaseBin/ChOma/src/MachO.c loc=L304 community=26]
NODE macho_init_for_writing() [src=BaseBin/ChOma/src/MachO.c loc=L740 community=26]
NODE macho_free() [src=BaseBin/ChOma/src/MachO.c loc=L807 community=26]
NODE macho_get_stream() [src=BaseBin/ChOma/src/MachO.c loc=L86 community=43]
NODE macho_parse_fileset_machos() [src=BaseBin/ChOma/src/MachO.c loc=L675 community=26]
NODE macho_init() [src=BaseBin/ChOma/src/MachO.c loc=L715 community=26]
NODE macho_read_string_at_offset() [src=BaseBin/ChOma/src/MachO.c loc=L31 community=26]
NODE macho_translate_fileoff_to_vmaddr() [src=BaseBin/ChOma/src/MachO.c loc=L117 community=26]
NODE macho_translate_vmaddr_to_fileoff() [src=BaseBin/ChOma/src/MachO.c loc=L132 community=26]
NODE macho_write_at_offset() [src=BaseBin/ChOma/src/MachO.c loc=L81 community=26]
NODE macho_get_mach_header_size() [src=BaseBin/ChOma/src/MachO.c loc=L101 community=26]
NODE _macho_parse() [src=BaseBin/ChOma/src/MachO.c loc=L703 community=26]
NODE macho_read_at_vmaddr() [src=BaseBin/ChOma/src/MachO.c loc=L148 community=26]
NODE macho_read_trie_node_at_offset() [src=BaseBin/ChOma/src/MachO.c loc=L271 community=26]
NODE macho_get_base_address() [src=BaseBin/ChOma/src/MachO.c loc=L517 community=26]
NODE macho_is_encrypted() [src=BaseBin/ChOma/src/MachO.c loc=L791 community=26]
NODE macho_read_string_at_vmaddr() [src=BaseBin/ChOma/src/MachO.c loc=L169 community=26]
NODE macho_read_uleb128_at_offset() [src=BaseBin/ChOma/src/MachO.c loc=L43 community=26]
NODE macho_write_at_vmaddr() [src=BaseBin/ChOma/src/MachO.c loc=L189 community=26]
NODE macho_array_create_for_paths() [src=BaseBin/ChOma/src/MachO.c loc=L769 community=26]
NODE macho_enumerate_rpaths() [src=BaseBin/ChOma/src/MachO.c loc=L484 community=26]
NODE macho_enumerate_sections() [src=BaseBin/ChOma/src/MachO.c loc=L254 community=26]
NODE macho_enumerate_segments() [src=BaseBin/ChOma/src/MachO.c loc=L244 community=26]
NODE macho_get_filetype() [src=BaseBin/ChOma/src/MachO.c loc=L91 community=26]
NODE macho_get_mach_header_and_commands_size() [src=BaseBin/ChOma/src/MachO.c loc=L106 community=26]
NODE macho_lookup_segment_by_addr() [src=BaseBin/ChOma/src/MachO.c loc=L582 community=26]
NODE macho_parse_segments() [src=BaseBin/ChOma/src/MachO.c loc=L608 community=26]
NODE macho_get_containing_cache() [src=BaseBin/ChOma/src/MachO.c loc=L112 community=26]
NODE macho_lookup_section_by_addr() [src=BaseBin/ChOma/src/MachO.c loc=L595 community=26]
NODE macho_get_mach_header() [src=BaseBin/ChOma/src/MachO.c loc=L96 community=26]
NODE macho_enumerate_dependencies() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L448 community=25]
NODE macho_enumerate_function_starts() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L539 community=25]
NODE external/ChOma/src/MachO.c [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L1 community=25]
NODE macho_enumerate_load_commands() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L205 community=25]
NODE macho_read_at_offset() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L14 community=25]
NODE macho_enumerate_symbols() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L304 community=25]
NODE macho_init_for_writing() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L740 community=25]
NODE macho_free() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L807 community=25]
NODE macho_get_stream() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L86 community=25]
NODE macho_parse_fileset_machos() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L675 community=25]
NODE macho_get_base_address() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L517 community=25]
NODE macho_init() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L715 community=25]
NODE macho_read_string_at_offset() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L31 community=25]
NODE macho_translate_fileoff_to_vmaddr() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L117 community=25]
NODE macho_translate_vmaddr_to_fileoff() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L132 community=25]
NODE macho_write_at_offset() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L81 community=25]
NODE macho_get_mach_header_size() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L101 community=25]
NODE _macho_parse() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L703 community=25]
NODE macho_read_at_vmaddr() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L148 community=25]
NODE macho_read_trie_node_at_offset() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L271 community=25]
NODE macho_get_filetype() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L91 community=25]
NODE macho_is_encrypted() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L791 community=25]
NODE macho_read_string_at_vmaddr() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L169 community=25]
NODE macho_read_uleb128_at_offset() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L43 community=25]
NODE macho_write_at_vmaddr() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L189 community=25]
NODE macho_array_create_for_paths() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L769 community=17]
NODE macho_enumerate_rpaths() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L484 community=25]
NODE macho_enumerate_sections() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L254 community=25]
NODE macho_enumerate_segments() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L244 community=25]
NODE macho_get_mach_header_and_commands_size() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L106 community=25]
NODE macho_lookup_segment_by_addr() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L582 community=25]
NODE macho_parse_segments() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L608 community=25]
NODE macho_get_containing_cache() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L112 community=25]
NODE macho_lookup_section_by_addr() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L595 community=25]
NODE macho_get_mach_header() [src=BaseBin/XPF/external/ChOma/src/MachO.c loc=L96 community=25]
NODE BaseBin/ChOma/src/BufferedStream.c [src=BaseBin/ChOma/src/BufferedStream.c loc=L1 community=126]
NODE buffered_stream_hardclone() [src=BaseBin/ChOma/src/BufferedStream.c loc=L120 community=126]
NODE buffered_stream_softclone() [src=BaseBin/ChOma/src/BufferedStream.c loc=L101 community=126]
NODE buffered_stream_init_from_buffer() [src=BaseBin/ChOma/src/BufferedStream.c loc=L184 community=126]
NODE buffered_stream_init_from_buffer_nocopy() [src=BaseBin/ChOma/src/BufferedStream.c loc=L158 community=126]
NODE _buffered_stream_make_own_data() [src=BaseBin/ChOma/src/BufferedStream.c loc=L8 community=126]
NODE buffered_stream_write() [src=BaseBin/ChOma/src/BufferedStream.c loc=L32 community=126]
NODE buffered_stream_expand() [src=BaseBin/ChOma/src/BufferedStream.c loc=L81 community=126]
NODE buffered_stream_free() [src=BaseBin/ChOma/src/BufferedStream.c loc=L129 community=126]
NODE _buffered_stream_init() [src=BaseBin/ChOma/src/BufferedStream.c loc=L140 community=126]
NODE buffered_stream_get_raw_pointer() [src=BaseBin/ChOma/src/BufferedStream.c loc=L64 community=126]
NODE buffered_stream_get_size() [src=BaseBin/ChOma/src/BufferedStream.c loc=L57 community=126]
NODE buffered_stream_read() [src=BaseBin/ChOma/src/BufferedStream.c loc=L20 community=126]
NODE buffered_stream_trim() [src=BaseBin/ChOma/src/BufferedStream.c loc=L70 community=126]
NODE BaseBin/ChOma/src/BufferedStream.h [src=BaseBin/ChOma/src/BufferedStream.h loc=L1 community=10]
NODE BaseBin/ChOma/src/CSBlob.c [src=BaseBin/ChOma/src/CSBlob.c loc=L1 community=29]
NODE macho_replace_code_signature() [src=BaseBin/ChOma/src/CSBlob.c loc=L131 community=29]
NODE macho_read_code_signature() [src=BaseBin/ChOma/src/CSBlob.c loc=L116 community=29]
NODE macho_find_code_signature_bounds() [src=BaseBin/ChOma/src/CSBlob.c loc=L100 community=29]
NODE macho_parse_signature_blob_to_der_encoded_data() [src=BaseBin/ChOma/src/CSBlob.c loc=L95 community=29]
NODE csd_blob_read() [src=BaseBin/ChOma/src/CSBlob.c loc=L183 community=55]
NODE csd_blob_get_size() [src=BaseBin/ChOma/src/CSBlob.c loc=L227 community=29]
NODE csd_blob_write() [src=BaseBin/ChOma/src/CSBlob.c loc=L194 community=55]
NODE csd_superblob_decode() [src=BaseBin/ChOma/src/CSBlob.c loc=L258 community=29]
NODE csd_blob_init() [src=BaseBin/ChOma/src/CSBlob.c loc=L171 community=29]
NODE csd_superblob_print_content() [src=BaseBin/ChOma/src/CSBlob.c loc=L481 community=29]
NODE _csd_blob_fix_length() [src=BaseBin/ChOma/src/CSBlob.c loc=L188 community=29]
NODE csd_blob_free() [src=BaseBin/ChOma/src/CSBlob.c loc=L242 community=29]
NODE csd_superblob_append_blob() [src=BaseBin/ChOma/src/CSBlob.c loc=L387 community=29]
NODE csd_superblob_find_blob() [src=BaseBin/ChOma/src/CSBlob.c loc=L327 community=29]
NODE csd_superblob_replace_blob() [src=BaseBin/ChOma/src/CSBlob.c loc=L401 community=29]
NODE csd_blob_delete() [src=BaseBin/ChOma/src/CSBlob.c loc=L208 community=29]
NODE csd_blob_insert() [src=BaseBin/ChOma/src/CSBlob.c loc=L201 community=29]
NODE csd_superblob_encode() [src=BaseBin/ChOma/src/CSBlob.c loc=L282 community=29]
NODE csd_superblob_insert_blob_at_index() [src=BaseBin/ChOma/src/CSBlob.c loc=L366 community=29]
NODE csd_superblob_remove_blob() [src=BaseBin/ChOma/src/CSBlob.c loc=L414 community=29]
NODE csd_blob_read_string() [src=BaseBin/ChOma/src/CSBlob.c loc=L215 community=55]
NODE csd_superblob_calculate_best_cdhash() [src=BaseBin/ChOma/src/CSBlob.c loc=L473 community=29]
NODE csd_superblob_find_best_code_directory() [src=BaseBin/ChOma/src/CSBlob.c loc=L453 community=29]
NODE csd_superblob_free() [src=BaseBin/ChOma/src/CSBlob.c loc=L514 community=29]
NODE csd_superblob_insert_blob_after_blob() [src=BaseBin/ChOma/src/CSBlob.c loc=L359 community=29]
NODE csd_superblob_remove_blob_at_index() [src=BaseBin/ChOma/src/CSBlob.c loc=L431 community=29]
NODE csd_blob_write_string() [src=BaseBin/ChOma/src/CSBlob.c loc=L220 community=29]
NODE csd_superblob_find_blob_by_magic() [src=BaseBin/ChOma/src/CSBlob.c loc=L342 community=29]
NODE csd_superblob_init() [src=BaseBin/ChOma/src/CSBlob.c loc=L250 community=29]
NODE macho_extract_cs_to_file() [src=BaseBin/ChOma/src/CSBlob.c loc=L163 community=29]
NODE csd_blob_set_type() [src=BaseBin/ChOma/src/CSBlob.c loc=L237 community=29]
NODE cs_blob_magic_to_string() [src=BaseBin/ChOma/src/CSBlob.c loc=L13 community=29]
NODE cs_slot_type_to_string() [src=BaseBin/ChOma/src/CSBlob.c loc=L41 community=29]
NODE csd_blob_get_type() [src=BaseBin/ChOma/src/CSBlob.c loc=L232 community=29]
NODE BaseBin/ChOma/src/CSBlob.h [src=BaseBin/ChOma/src/CSBlob.h loc=L1 community=10]
NODE BaseBin/ChOma/src/CachePatching.h [src=BaseBin/ChOma/src/CachePatching.h loc=L1 community=157]
... (truncated — 1180 more nodes cut by ~5000-token budget. Narrow with context_filter=['call'] or use get_node for a specific symbol)
```

## Q5

**Question:** How do UI controllers start the jailbreak and receive state, progress, logs, and errors?

**Exit code:** 0

```text
Graph: Dopamine-roothide-reconstruction-9617d75f-20261124T024805Z/evidence/source/graphify/graph.json (6291 nodes) | Traversal: BFS depth=3 | Start: ['-runWithErrordidRemoveJailbreakshowLogs', '-updateJailbreakState', '_ANEErrors', '-start', 'stateWriteLock()', 'jailbreakd.c', 'DOProgressiveBlurView', '+setupViewControllerStyle', 'jbserver_received_mach_message()'] | 1386 nodes found

[!] TRUNCATED: showing 144 of 1386 nodes (~5000-token budget). The answer may be among the 1242 cut nodes — raise the token budget to 42574 to get all 1386 (CLI: --budget 42574, MCP: token_budget=42574) or narrow the query (e.g. context_filter=['call'], or get_node for a specific symbol).

NODE -runWithErrordidRemoveJailbreakshowLogs [src=Application/Dopamine/Jailbreak/DOJailbreaker.h loc=L19 community=71]
NODE -updateJailbreakState [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.m loc=L279 community=18]
NODE _ANEErrors [src=Application/Dopamine/Exploits/weightBufs/exploit/AppleNeuralEngine/_ANEErrors.h loc=L10 community=174]
NODE DOProgressiveBlurView [src=Application/Dopamine/UI/Log/DOProgressiveBlurView.h loc=L12 community=191]
NODE jailbreakd.c [src=BaseBin/libroothider/src/jailbreakd.c loc=L1 community=89]
NODE stateWriteLock() [src=BaseBin/libroothider/src/blacklist.cpp loc=L45 community=87]
NODE +setupViewControllerStyle [src=Application/Dopamine/UI/Settings/PSLists/DOPSListController.h loc=L17 community=45]
NODE jbserver_received_mach_message() [src=BaseBin/launchdhook/src/jbserver/jbserver_mach.c loc=L46 community=14]
NODE -start [src=Application/Dopamine/Exploits/weightBufs/exploit/AppleNeuralEngine/_ANEDeviceController.h loc=L33 community=107]
NODE DOJailbreaker [src=Application/Dopamine/Jailbreak/DOJailbreaker.h loc=L14 community=71]
NODE DOJailbreaker.h [src=Application/Dopamine/Jailbreak/DOJailbreaker.h loc=L1 community=62]
NODE -applyContiguousMappingWorkaround [src=Application/Dopamine/Jailbreak/DOJailbreaker.h loc=L23 community=71]
NODE -contiguousMappingWorkaroundNeeded [src=Application/Dopamine/Jailbreak/DOJailbreaker.h loc=L22 community=71]
NODE -finalize [src=Application/Dopamine/Jailbreak/DOJailbreaker.h loc=L20 community=71]
NODE -unregisterJailbreakApps [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.m loc=L490 community=18]
NODE DOEnvironmentManager.m [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.m loc=L1 community=32]
NODE -spawnJbctlAsRootWithArgs [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.m loc=L385 community=18]
NODE -init [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.m loc=L48 community=18]
NODE -deviceSupportsFaceID [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.m loc=L818 community=18]
NODE -runTrollStoreAction [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.m loc=L456 community=18]
NODE _ANEErrors.h [src=Application/Dopamine/Exploits/weightBufs/exploit/AppleNeuralEngine/_ANEErrors.h loc=L1 community=117]
NODE +createErrorWithCodedescription [src=Application/Dopamine/Exploits/weightBufs/exploit/AppleNeuralEngine/_ANEErrors.h loc=L11 community=174]
NODE +entitlementErrorForMethod [src=Application/Dopamine/Exploits/weightBufs/exploit/AppleNeuralEngine/_ANEErrors.h loc=L14 community=174]
NODE +missingCodeSigningErrorForMethod [src=Application/Dopamine/Exploits/weightBufs/exploit/AppleNeuralEngine/_ANEErrors.h loc=L19 community=174]
NODE +priorityErrorForMethod [src=Application/Dopamine/Exploits/weightBufs/exploit/AppleNeuralEngine/_ANEErrors.h loc=L15 community=174]
NODE +programCreationErrorForMethod [src=Application/Dopamine/Exploits/weightBufs/exploit/AppleNeuralEngine/_ANEErrors.h loc=L17 community=174]
NODE +programInferenceOtherErrorForMethod [src=Application/Dopamine/Exploits/weightBufs/exploit/AppleNeuralEngine/_ANEErrors.h loc=L13 community=174]
NODE +programInferenceOverflowErrorForMethod [src=Application/Dopamine/Exploits/weightBufs/exploit/AppleNeuralEngine/_ANEErrors.h loc=L12 community=174]
NODE +programLoadErrorForMethod [src=Application/Dopamine/Exploits/weightBufs/exploit/AppleNeuralEngine/_ANEErrors.h loc=L18 community=174]
NODE +timeoutErrorForMethod [src=Application/Dopamine/Exploits/weightBufs/exploit/AppleNeuralEngine/_ANEErrors.h loc=L16 community=174]
NODE DOProgressiveBlurView.h [src=Application/Dopamine/UI/Log/DOProgressiveBlurView.h loc=L1 community=23]
NODE -initWithGradientMaskmaxBlurRadius [src=Application/Dopamine/UI/Log/DOProgressiveBlurView.h loc=L14 community=191]
NODE DOProgressiveBlurView.m [src=Application/Dopamine/UI/Log/DOProgressiveBlurView.m loc=L1 community=191]
NODE -layoutSubviews [src=Application/Dopamine/UI/Log/DOProgressiveBlurView.m loc=L46 community=191]
NODE DOBlurEffect [src=Application/Dopamine/UI/Log/DOProgressiveBlurView.m loc=L13 community=191]
NODE UIBlurEffect [src=Application/Dopamine/UI/Log/DOProgressiveBlurView.m loc=L10 community=191]
NODE -effectSettings [src=Application/Dopamine/UI/Log/DOProgressiveBlurView.m loc=L16 community=191]
NODE -effectSettings [src=Application/Dopamine/UI/Log/DOProgressiveBlurView.m loc=L11 community=191]
NODE jailbreakdXpcRequest() [src=BaseBin/libroothider/src/jailbreakd.c loc=L284 community=89]
NODE jailbreakdClientPort() [src=BaseBin/libroothider/src/jailbreakd.c loc=L245 community=89]
NODE jailbreakdClientPortFastGet() [src=BaseBin/libroothider/src/jailbreakd.c loc=L65 community=89]
NODE jailbreakdServerPort() [src=BaseBin/libroothider/src/jailbreakd.c loc=L238 community=89]
NODE reactiveJailbreakdPort() [src=BaseBin/libroothider/src/jailbreakd.c loc=L178 community=89]
NODE setJailbreakdProcess() [src=BaseBin/libroothider/src/jailbreakd.c loc=L79 community=89]
NODE spawnJailbreakd() [src=BaseBin/libroothider/src/jailbreakd.c loc=L98 community=89]
NODE initJailbreakd() [src=BaseBin/libroothider/src/jailbreakd.c loc=L158 community=89]
NODE jbdExecTraceStart() [src=BaseBin/libroothider/src/jailbreakd.c loc=L423 community=89]
NODE jbdSpawnExecStart() [src=BaseBin/libroothider/src/jailbreakd.c loc=L392 community=89]
NODE jbdExecTraceCancel() [src=BaseBin/libroothider/src/jailbreakd.c loc=L441 community=89]
NODE jbdSpawnExecCancel() [src=BaseBin/libroothider/src/jailbreakd.c loc=L408 community=89]
NODE jbdSpawnPatchChild() [src=BaseBin/libroothider/src/jailbreakd.c loc=L360 community=89]
NODE jbdSystemwideLog() [src=BaseBin/libroothider/src/jailbreakd.c loc=L330 community=89]
NODE registerServerPort() [src=BaseBin/libroothider/src/jailbreakd.c loc=L40 community=89]
NODE jbdSpinlockFixOnly() [src=BaseBin/libroothider/src/jailbreakd.c loc=L376 community=89]
NODE jbdTestCall() [src=BaseBin/libroothider/src/jailbreakd.c loc=L313 community=89]
NODE enableJBDLog() [src=BaseBin/libroothider/src/jailbreakd.c loc=L22 community=89]
NODE jailbreakd.h [src=BaseBin/libroothider/src/jailbreakd.h loc=L1 community=2]
NODE -startJailbreak [src=Application/Dopamine/UI/DOMainViewController.m loc=L214 community=71]
NODE -jailbreakButtonTitle [src=Application/Dopamine/UI/DOMainViewController.m loc=L191 community=48]
NODE -simulateJailbreak [src=Application/Dopamine/UI/DOMainViewController.m loc=L334 community=48]
NODE jbserver_received_xpc_message() [src=BaseBin/libjailbreak/src/jbserver.c loc=L6 community=96]
NODE jbserver.c [src=BaseBin/libjailbreak/src/jbserver.c loc=L1 community=13]
NODE jbserver_received_boomerang_xpc_message() [src=BaseBin/libjailbreak/src/jbserver_boomerang.c loc=L109 community=96]
NODE jbserver_boomerang.c [src=BaseBin/libjailbreak/src/jbserver_boomerang.c loc=L1 community=15]
NODE boomerang_sign_thread() [src=BaseBin/libjailbreak/src/jbserver_boomerang.c loc=L37 community=15]
NODE boomerang_get_sysinfo() [src=BaseBin/libjailbreak/src/jbserver_boomerang.c loc=L49 community=96]
NODE stateWriteUnlock() [src=BaseBin/libroothider/src/blacklist.cpp loc=L49 community=87]
NODE stateLockInit() [src=BaseBin/libroothider/src/blacklist.cpp loc=L33 community=87]
NODE stateReadLock() [src=BaseBin/libroothider/src/blacklist.cpp loc=L37 community=87]
NODE stateReadUnlock() [src=BaseBin/libroothider/src/blacklist.cpp loc=L41 community=87]
NODE initBlacklistState() [src=BaseBin/libroothider/src/blacklist.cpp loc=L54 community=87]
NODE JBLogSetLogDir() [src=BaseBin/libroothider/src/log.c loc=L31 community=160]
NODE arm64_kcall_prepare_state() [src=BaseBin/libjailbreak/src/kcall_arm64.c loc=L53 community=51]
NODE kcall_arm64.c [src=BaseBin/libjailbreak/src/kcall_arm64.c loc=L1 community=15]
NODE arm64_kcall_init() [src=BaseBin/libjailbreak/src/kcall_arm64.c loc=L109 community=64]
NODE -locateJailbreakRoot [src=Application/Dopamine/Jailbreak/DOBootstrapper.m loc=L1554 community=328]
NODE -doBootstrap [src=Application/Dopamine/Jailbreak/DOBootstrapper.m loc=L1177 community=24]
NODE -extractBootstrapwithCompletion [src=Application/Dopamine/Jailbreak/DOBootstrapper.m loc=L230 community=24]
NODE -extractTartoPath [src=Application/Dopamine/Jailbreak/DOBootstrapper.m loc=L59 community=24]
NODE -bootstrapVersion [src=Application/Dopamine/Jailbreak/DOBootstrapper.m loc=L196 community=24]
NODE -fixupPathPermissions [src=Application/Dopamine/Jailbreak/DOBootstrapper.m loc=L144 community=24]
NODE -isPrivatePrebootMountedWritable [src=Application/Dopamine/Jailbreak/DOBootstrapper.m loc=L106 community=24]
NODE -remountPrivatePrebootWritable [src=Application/Dopamine/Jailbreak/DOBootstrapper.m loc=L113 community=24]
NODE -deleteSymlinkAtPatherror [src=Application/Dopamine/Jailbreak/DOBootstrapper.m loc=L68 community=24]
NODE -patchBasebinDaemonPlists [src=Application/Dopamine/Jailbreak/DOBootstrapper.m loc=L187 community=24]
NODE -refreshJailbreakApps [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.h loc=L57 community=18]
NODE -isJailbrokenWithOtherJailbreak [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.h loc=L32 community=18]
NODE -locateJailbreakRoot [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.h loc=L45 community=18]
NODE -updateJailbreakFromTIPA [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.h loc=L61 community=18]
NODE DOEnvironmentManager [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.h loc=L13 community=18]
NODE +sharedManager [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.h loc=L21 community=35]
NODE -isJailbroken [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.h loc=L31 community=18]
NODE -jailbrokenVersion [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.h loc=L34 community=18]
NODE -runUnsandboxed [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.h loc=L51 community=18]
NODE -runAsRoot [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.h loc=L52 community=18]
NODE DOEnvironmentManager.h [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.h loc=L1 community=22]
NODE -isInstalledThroughTrollStore [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.h loc=L30 community=18]
NODE -updateBootLogo [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.h loc=L83 community=18]
NODE -deleteBootstrap [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.h loc=L81 community=18]
NODE -isSupported [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.h loc=L38 community=18]
NODE -setTweakInjectionEnabled [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.h loc=L64 community=18]
NODE -changeMobilePassword [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.h loc=L59 community=18]
NODE -isPACBypassRequired [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.h loc=L76 community=18]
NODE -setIDownloadEnabledneedsUnsandbox [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.h loc=L66 community=18]
NODE -setIDownloadLoadedneedsUnsandbox [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.h loc=L67 community=18]
NODE -isIDownloadEnabled [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.h loc=L65 community=18]
NODE -isPPLBypassRequired [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.h loc=L77 community=18]
NODE -reboot [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.h loc=L58 community=18]
NODE -rebootUserspace [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.h loc=L55 community=18]
NODE -reinstallPackageManagers [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.h loc=L82 community=18]
NODE -prepareBootstrap [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.h loc=L79 community=24]
NODE -rebuildIconCache [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.h loc=L56 community=18]
NODE -respring [src=Application/Dopamine/Jailbreak/DOEnvironmentManager.h loc=L54 community=18]
NODE -removeJailbreak [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L555 community=71]
NODE DOJailbreaker.m [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L1 community=22]
NODE -doExploitation [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L173 community=81]
NODE -cleanUpExploits [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L245 community=71]
NODE -gatherSystemInformation [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L69 community=71]
NODE -buildPhysRWPrimitive [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L230 community=71]
NODE -elevatePrivileges [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L253 community=71]
NODE -finalizeBootstrapIfNeeded [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L572 community=71]
NODE -injectLaunchdHook [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L398 community=71]
NODE -loadBasebinTrustcache [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L367 community=71]
NODE -cleanUpPostExploitation [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L577 community=71]
NODE -ensureDevModeEnabled [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L335 community=71]
NODE -showNonDefaultSystemApps [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L328 community=71]
NODE -contiguousMappingWorks [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L826 community=71]
NODE -allocatePurpleGfxMemWithSize [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L805 community=71]
NODE -ensureNoDuplicateApps [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L490 community=218]
NODE -surfaceIsContiguous [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L814 community=71]
NODE -crashBackboardd [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L845 community=71]
NODE -crashBackboardd_15 [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L898 community=71]
NODE JBErrorCodeFailedCleanup [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L56 community=81]
NODE JBErrorCode [src=Application/Dopamine/Jailbreak/DOJailbreaker.m loc=L50 community=141]
NODE DOJailbreakButton.h [src=Application/Dopamine/UI/DOJailbreakButton.h loc=L1 community=23]
NODE DOJailbreakButton [src=Application/Dopamine/UI/DOJailbreakButton.h loc=L17 community=53]
NODE -unlockMutex [src=Application/Dopamine/UI/DOJailbreakButton.h loc=L31 community=53]
NODE -lockMutex [src=Application/Dopamine/UI/DOJailbreakButton.h loc=L30 community=53]
NODE -expandButton [src=Application/Dopamine/UI/DOJailbreakButton.h loc=L28 community=53]
NODE -initWithAction [src=Application/Dopamine/UI/DOJailbreakButton.h loc=L27 community=20]
NODE DOJailbreakButton.m [src=Application/Dopamine/UI/DOJailbreakButton.m loc=L1 community=23]
NODE -setupPackageManagerPicker [src=Application/Dopamine/UI/DOJailbreakButton.m loc=L111 community=53]
NODE jbclient_jailbreakd_lookup() [src=BaseBin/libjailbreak/src/jbclient_roothide.c loc=L40 community=113]
NODE jbclient_roothide.c [src=BaseBin/libjailbreak/src/jbclient_roothide.c loc=L1 community=113]
... (truncated — 1242 more nodes cut by ~5000-token budget. Narrow with context_filter=['call'] or use get_node for a specific symbol)
```

## Most connected nodes

**Exit code:** 0

```json
[
  {
    "id": "application_frameworks_preferences_framework_headers_pslistcontroller_pslistcontroller",
    "label": "PSListController",
    "degree": 169
  },
  {
    "id": "application_frameworks_preferences_framework_headers_psspecifier_psspecifier",
    "label": "PSSpecifier",
    "degree": 81
  },
  {
    "id": "basebin_choma_src_dyld_cache_format_dyld_cache_header",
    "label": "dyld_cache_header",
    "degree": 78
  },
  {
    "id": "basebin_xpf_external_choma_src_dyld_cache_format_dyld_cache_header",
    "label": "dyld_cache_header",
    "degree": 78
  },
  {
    "id": "basebin_external_include_dyld_cache_format_dyld_cache_header",
    "label": "dyld_cache_header",
    "degree": 76
  },
  {
    "id": "basebin_external_modules_litehook_external_include_dyld_cache_format_dyld_cache_header",
    "label": "dyld_cache_header",
    "degree": 76
  },
  {
    "id": "application_frameworks_preferences_framework_headers_pstablecell_pstablecell",
    "label": "PSTableCell",
    "degree": 74
  },
  {
    "id": "basebin_xpf_external_choma_src_patchfinder_pfmetric_free",
    "label": "pfmetric_free()",
    "degree": 62
  },
  {
    "id": "basebin_xpf_external_choma_src_patchfinder_pfmetric_run",
    "label": "pfmetric_run()",
    "degree": 62
  },
  {
    "id": "application_dopamine_jailbreak_doenvironmentmanager_doenvironmentmanager",
    "label": "DOEnvironmentManager",
    "degree": 55
  },
  {
    "id": "basebin_xpf_src_xpf_xpf_item_resolve",
    "label": "xpf_item_resolve()",
    "degree": 54
  },
  {
    "id": "basebin_xpf_external_choma_src_patchfinder_pfsec_read32",
    "label": "pfsec_read32()",
    "degree": 53
  },
  {
    "id": "basebin_libjailbreak_src_primitives_kread_ptr",
    "label": "kread_ptr()",
    "degree": 52
  },
  {
    "id": "basebin_xpf_external_choma_src_patchfinder_pfmetric_xref_init",
    "label": "pfmetric_xref_init()",
    "degree": 46
  },
  {
    "id": "basebin_xpf_external_img4lib_libder_libder_deritem",
    "label": "DERItem",
    "degree": 46
  },
  {
    "id": "application_dopamine_exploits_weightbufs_exploit_appleneuralengine_anemodel_anemodel",
    "label": "_ANEModel",
    "degree": 45
  },
  {
    "id": "application_dopamine_ui_settings_dosettingscontroller_dosettingscontroller",
    "label": "DOSettingsController",
    "degree": 43
  },
  {
    "id": "basebin_xpf_external_choma_src_patchfinder_pfsec_find_next_inst",
    "label": "pfsec_find_next_inst()",
    "degree": 43
  },
  {
    "id": "application_dopamine_jailbreak_doenvironmentmanager_doenvironmentmanager_sharedmanager",
    "label": "+sharedManager",
    "degree": 43
  },
  {
    "id": "application_dopamine_exploits_weightbufs_exploit_iokit_io_connect_t",
    "label": "io_connect_t",
    "degree": 43
  },
  {
    "id": "application_dopamine_jailbreak_dobootstrapper_dobootstrapper",
    "label": "DOBootstrapper",
    "degree": 41
  },
  {
    "id": "basebin_xpf_external_choma_src_patchfinder_arm64_pfsec_arm64_resolve_adrp_ldr_str_add_reference_auto",
    "label": "pfsec_arm64_resolve_adrp_ldr_str_add_reference_auto()",
    "degree": 40
  },
  {
    "id": "application_dopamine_exploits_weightbufs_exploit_aneprogram_zincomputeprogramstruct",
    "label": "ZinComputeProgramStruct",
    "degree": 39
  },
  {
    "id": "basebin_libjailbreak_src_primitives_kread64",
    "label": "kread64()",
    "degree": 39
  },
  {
    "id": "basebin_libjailbreak_src_jbclient_xpc_jbserver_xpc_send",
    "label": "jbserver_xpc_send()",
    "degree": 39
  },
  {
    "id": "basebin_xpf_external_choma_src_patchfinder_pfmetric_string_init",
    "label": "pfmetric_string_init()",
    "degree": 36
  },
  {
    "id": "basebin_xpf_external_choma_src_patchfinder_pfsec_find_prev_inst",
    "label": "pfsec_find_prev_inst()",
    "degree": 35
  },
  {
    "id": "basebin_external_include_xpc_xpc_xpc_object_t",
    "label": "xpc_object_t",
    "degree": 34
  },
  {
    "id": "basebin_xpf_external_choma_src_arm64_arm64_gen_ldr_imm",
    "label": "arm64_gen_ldr_imm()",
    "degree": 32
  },
  {
    "id": "application_dopamine_ui_douimanager_douimanager",
    "label": "DOUIManager",
    "degree": 31
  }
]
```
