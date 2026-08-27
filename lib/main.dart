import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'features/discovery/discovery_service.dart';
import 'features/transfer/transfer_server.dart';
import 'features/transfer/transfer_client.dart';
import 'permissions/permission_manager.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final DiscoveryService discoveryService =
      DiscoveryService();

  late final TransferServer transferServer;

  final TransferClient transferClient =
      TransferClient();

  final PermissionManager permissionManager =
      PermissionManager();

  final ImagePicker picker = ImagePicker();

  File? selectedFile;

  List<File> receivedFiles = [];

  String status = 'Starting...';

  bool isConnected = false;
  bool isSending = false;

  double progress = 0.0;

  @override
  void initState() {
    super.initState();

    transferServer = TransferServer(
      onFileReceived: (filePath) async {
        print(
          'File received by UI: $filePath',
        );

        await loadReceivedFiles();

        if (!mounted) return;

        setState(() {
          status =
              'File received successfully!';
        });
      },
    );

    startApp();
  }


  // LOAD RECEIVED FILES
  Future<void> loadReceivedFiles() async {
    final files =
        await transferServer.getReceivedFiles();

    if (!mounted) return;

    setState(() {
      receivedFiles = files;
    });
  }


  // START APP

  Future<void> startApp() async {
    final granted =
        await permissionManager
            .requestAllPermissions();

    if (!granted) {
      if (!mounted) return;

      setState(() {
        status = 'Permissions denied';
      });

      return;
    }

    // Load previously received files.
    await loadReceivedFiles();

    if (!mounted) return;

    setState(() {
      status =
          'Starting transfer server...';
    });

    await transferServer
        .startListening(4040);

    await Future.delayed(
      const Duration(seconds: 2),
    );

    if (!mounted) return;

    setState(() {
      status =
          'Advertising and searching for peers...';
    });

    discoveryService
        .startAdvertising(4040);

    await Future.delayed(
      const Duration(seconds: 1),
    );

    discoveryService.deviceDiscovery(
      (peer) async {
        print(
          'Peer host: ${peer.host}',
        );

        print(
          'Peer port: ${peer.port}',
        );

        print(
          'Peer addresses: ${peer.addresses}',
        );

        final address =
            peer.addresses?.isNotEmpty == true
                ? peer.addresses!.first.address
                : peer.host;

        if (address == null) {
          print(
            'No address found for peer',
          );

          if (!mounted) return;

          setState(() {
            status =
                'Peer found but no address available';
          });

          return;
        }

        if (!mounted) return;

        setState(() {
          status =
              'Connecting to peer...';
        });

        try {
          await transferClient.connect(
            address,
            peer.port ?? 4040,
          );

          if (!mounted) return;

          setState(() {
            isConnected = true;

            status =
                'Connected! Select a photo or video.';
          });

          print(
            'Connected to peer',
          );
        } catch (e) {
          print(
            'Connection error: $e',
          );

          if (!mounted) return;

          setState(() {
            status =
                'Connection failed';
          });
        }
      },
    );
  }

  // ------------------------------------------------------------
  // PICK IMAGE
  // ------------------------------------------------------------
  Future<void> pickImage() async {
    final XFile? pickedFile =
        await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile == null) {
      return;
    }

    if (!mounted) return;

    setState(() {
      selectedFile =
          File(pickedFile.path);

      status =
          'Photo selected: ${pickedFile.name}';
    });
  }


  // PICK VIDEO
  Future<void> pickVideo() async {
    final XFile? pickedFile =
        await picker.pickVideo(
      source: ImageSource.gallery,
    );

    if (pickedFile == null) {
      return;
    }

    if (!mounted) return;

    setState(() {
      selectedFile =
          File(pickedFile.path);

      status =
          'Video selected: ${pickedFile.name}';
    });
  }


  // SEND FILE

  Future<void> sendSelectedFile() async {
    if (selectedFile == null) {
      setState(() {
        status =
            'Please select a file first';
      });

      return;
    }

    if (!isConnected) {
      setState(() {
        status =
            'Not connected to a peer yet';
      });

      return;
    }

    setState(() {
      isSending = true;

      progress = 0.0;

      status =
          'Sending file...';
    });

    try {
      await transferClient.sendFile(
        selectedFile!,
        onProgress: (sent, total) {
          if (!mounted) return;

          setState(() {
            progress =
                sent / total;
          });
        },
      );

      if (!mounted) return;

      setState(() {
        progress = 1.0;

        status =
            'File sent successfully!';
      });
    } catch (e) {
      print(
        'Send error: $e',
      );

      if (!mounted) return;

      setState(() {
        status =
            'Failed to send file';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        isSending = false;
      });
    }
  }


  // CHECK IMAGE

  bool isImageFile(File file) {
    final extension =
        file.path
            .split('.')
            .last
            .toLowerCase();

    return extension == 'jpg' ||
        extension == 'jpeg' ||
        extension == 'png' ||
        extension == 'gif' ||
        extension == 'webp' ||
        extension == 'bmp';
  }

  
  // BUILD
  
  @override
  Widget build(BuildContext context) {
    // Only show images in the image grid.
    final imageFiles = receivedFiles
        .where(isImageFile)
        .toList();

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text(
            'VConnect',
          ),
          centerTitle: true,
        ),


        body: SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.all(20),

            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,

              children: [
                Icon(
                  isConnected
                      ? Icons.wifi
                      : Icons.wifi_find,
                  size: 70,
                ),

                const SizedBox(
                  height: 20,
                ),


                Text(
                  status,
                  textAlign:
                      TextAlign.center,
                  style:
                      const TextStyle(
                    fontSize: 18,
                  ),
                ),

                const SizedBox(
                  height: 30,
                ),

                ElevatedButton.icon(
                  onPressed:
                      isSending
                          ? null
                          : pickImage,

                  icon:
                      const Icon(
                    Icons.image,
                  ),

                  label:
                      const Text(
                    'Pick Photo',
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                ElevatedButton.icon(
                  onPressed:
                      isSending
                          ? null
                          : pickVideo,

                  icon:
                      const Icon(
                    Icons.video_library,
                  ),

                  label:
                      const Text(
                    'Pick Video',
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),


                if (selectedFile != null)
                  Text(
                    'Selected: '
                    '${selectedFile!.path.split('/').last}',
                    textAlign:
                        TextAlign.center,
                  ),

                const SizedBox(
                  height: 30,
                ),


                if (isSending) ...[
                  LinearProgressIndicator(
                    value: progress,
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  Text(
                    '${(progress * 100).toStringAsFixed(1)}%',
                    style:
                        const TextStyle(
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),
                ],


                ElevatedButton.icon(
                  onPressed:
                      selectedFile == null ||
                              !isConnected ||
                              isSending
                          ? null
                          : sendSelectedFile,

                  icon:
                      const Icon(
                    Icons.send,
                  ),

                  label:
                      const Text(
                    'Send',
                  ),
                ),

                const SizedBox(
                  height: 30,
                ),

                if (imageFiles.isNotEmpty) ...[
                  const Align(
                    alignment:
                        Alignment.centerLeft,

                    child: Text(
                      'Received Files',

                      style:
                          TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 15,
                  ),

                  GridView.builder(
                    shrinkWrap: true,

                    physics:
                        const NeverScrollableScrollPhysics(),

                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,

                      crossAxisSpacing:
                          10,

                      mainAxisSpacing:
                          10,

                      childAspectRatio:
                          1,
                    ),

                    itemCount:
                        imageFiles.length,

                    itemBuilder:
                        (context, index) {
                      final file =
                          imageFiles[index];

                      return ClipRRect(
                        borderRadius:
                            BorderRadius.circular(
                          10,
                        ),

                        child:
                            Image.file(
                          file,

                          fit:
                              BoxFit.cover,

                          errorBuilder:
                              (
                            context,
                            error,
                            stackTrace,
                          ) {
                            return const Center(
                              child:
                                  Icon(
                                Icons
                                    .broken_image,
                                size: 40,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}