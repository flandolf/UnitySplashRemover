// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String version = "1.0.7";
  ScrollController _scrollController = ScrollController();
  final TextEditingController consoleController = TextEditingController();
  final TextEditingController unityVersion = TextEditingController();
  final TextEditingController gameName = TextEditingController();
  Set<String> unityVersions = {};
  Color selectedColor = Colors.red;

  void changeColor(Color color) {
    setState(() {
      selectedColor = color;
    });
  }

  void debug(String message) {
    consoleController.text += message;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  void getUnityVersions() async {
    unityVersions.clear(); // Clear the set before populating with new versions

    String unityPath = 'C:\\Program Files\\Unity\\Hub\\Editor';
    Directory unityHubDir = Directory(unityPath);
    List<FileSystemEntity> unityHubContents = unityHubDir.listSync();
    for (FileSystemEntity entity in unityHubContents) {
      if (entity is Directory) {
        String unityVersion = entity.path.split('\\').last;
        unityVersions.add(unityVersion);
      }
    }
  }

  bool isCustomVersion = false;
  bool isDarkMode = true;

  @override
  void initState() {
    super.initState();
    getUnityVersions();
    setState(() {
      unityVersion.text = unityVersions.first;
    });
  }

  @override
  void dispose() {
    consoleController.dispose();
    unityVersion.dispose();
    gameName.dispose();
    super.dispose();
  }

  Future<void> removeSplash() async {
    consoleController.text = "";
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['*'],
      allowMultiple: false,
    );
    if (result != null &&
        result.files.single.path!.endsWith("globalgamemanagers")) {
      debug("File selected: ${result.files.single.path}\n");
      debug("Game Name: ${gameName.text}\n");
      debug("Unity Version: ${unityVersion.text}\n");
      debug("Removing Splash Screen...\n");
      File file = File(result.files.single.path!);
      // Read file as bytes
      List<int> bytes = await file.readAsBytes();
      // Find the first occurrence of the game name
      String gameNameHex = stringToHex(gameName.text);
      int gameNameIndex = findHexPattern(bytes, gameNameHex, 1);
      if (gameNameIndex != -1) {
        debug("Game Name found at offset ${intToHex(gameNameIndex)}\n");
        // Find the first occurrence of the byte 0x3F (question mark) after the game name
        int questionMarkIndex = findByteAfterIndex(
            bytes, 0x3F, gameNameIndex + gameNameHex.length ~/ 2);
        if (questionMarkIndex != -1) {
          debug(
              "Question Mark found at offset ${intToHex(questionMarkIndex)}\n");
          // Change the byte after the question mark to 0x00
          bytes[questionMarkIndex + 1] = 0x00;
        } else {
          debug("Question Mark not found in the file.\n");
        }
      } else {
        debug("Game Name not found in the file.\n");
      }
      String versionHex = isCustomVersion
          ? stringToHex(unityVersion.text)
          : stringToHex(unityVersions.first);
      int versionIndex = findHexPattern(bytes, versionHex, 1);
      if (versionIndex != -1) {
        // Find the second occurrence of the Unity version
        int secondVersionIndex = findHexPattern(
            bytes, versionHex, versionIndex + versionHex.length ~/ 2);
        if (secondVersionIndex != -1) {
          debug(
              "Second Unity Version found at offset ${intToHex(secondVersionIndex)}\n");
          // Change the 20th byte before the second version to 0x01
          bytes[secondVersionIndex - 20] = 0x01;
          debug("Changed 20th byte before second version to 0x01\n");
        } else {
          debug("Second Unity Version not found in the file.\n");
        }
      } else {
        debug("Unity Version not found in the file.\n");
      }

      await file.writeAsBytes(bytes);
      debug("Splash Screen removed successfully.\n");
    } else {
      debug("No file selected.\n");
    }
  }

  // Helper function to convert a string to a hex representation
  String stringToHex(String input) {
    return input.codeUnits
        .map((unit) => unit.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  // Helper function to convert an integer to a hex string
  String intToHex(int input) {
    return "0x${input.toRadixString(16).toUpperCase()}";
  }

  // Helper function to find the first occurrence of a hex pattern in a list of bytes
  int findHexPattern(List<int> bytes, String pattern, int index) {
    List<int> patternBytes = [];
    for (int i = 0; i < pattern.length; i += 2) {
      patternBytes.add(int.parse(pattern.substring(i, i + 2), radix: 16));
    }
    for (int i = index; i < bytes.length; i++) {
      if (bytes[i] == patternBytes[0]) {
        bool found = true;
        for (int j = 1; j < patternBytes.length; j++) {
          if (bytes[i + j] != patternBytes[j]) {
            found = false;
            break;
          }
        }
        if (found) {
          return i;
        }
      }
    }
    return -1;
  }

  // Helper function to find the first occurrence of a byte after a given index in a list of bytes
  int findByteAfterIndex(List<int> bytes, int byte, int startIndex) {
    for (int i = startIndex; i < bytes.length; i++) {
      if (bytes[i] == byte) {
        return i;
      }
    }
    return -1;
  }

  final MaterialStateProperty<Icon?> thumbIcon =
      MaterialStateProperty.resolveWith<Icon?>(
    (Set<MaterialState> states) {
      if (states.contains(MaterialState.selected)) {
        return const Icon(Icons.mode_night);
      }
      return const Icon(Icons.sunny);
    },
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: selectedColor,
        useMaterial3: true,
        brightness: isDarkMode ? Brightness.dark : Brightness.light,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Text(
                'Unity Splash Remover',
                style: TextStyle(
                  fontSize: 32,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 10),
              Text(
                version,
                style: TextStyle(
                  fontSize: 12,
                ),
              )
            ],
          ),
          actions: [
            Switch(
              value: isDarkMode,
              thumbIcon: thumbIcon,
              onChanged: (value) {
                setState(() {
                  isDarkMode = value;
                });
              },
            ),
            SizedBox(width: 10),
            IconButton(
              icon: const Icon(Icons.color_lens),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return Theme(
                      data: ThemeData(
                        colorSchemeSeed: selectedColor,
                        useMaterial3: true,
                        brightness:
                            isDarkMode ? Brightness.dark : Brightness.light,
                      ),
                      child: AlertDialog(
                        title: const Text('Theme Color'),
                        content: BlockPicker(
                          pickerColor: selectedColor,
                          onColorChanged: (color) {
                            setState(() {
                              selectedColor = color;
                            });
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            SizedBox(
              width: 10,
            )
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Center(
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Game Name',
                  ),
                  controller: gameName,
                ),
                SizedBox(
                  height: 10,
                ),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Unity Version',
                  ),
                  value: unityVersion.text,
                  items: unityVersions.map((version) {
                    return DropdownMenuItem<String>(
                      key: UniqueKey(),
                      // Add a unique key to each DropdownMenuItem
                      value: version,
                      child: Text(version),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      unityVersion.text = value!;
                    });
                  },
                ),
                if (isCustomVersion) SizedBox(height: 10),
                if (isCustomVersion)
                  TextField(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Custom Unity Version',
                    ),
                    controller: unityVersion,
                  ),
                SizedBox(
                  height: 10,
                ),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        removeSplash();
                      },
                      child: Text('Remove Splash'),
                    ),
                    SizedBox(
                      width: 10,
                    ),
                    ElevatedButton(
                      onPressed: () {
                        consoleController.text = "";
                      },
                      child: Text('Clear Console'),
                    ),
                    SizedBox(
                      width: 10,
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          getUnityVersions();
                          unityVersion.text = unityVersions.isNotEmpty
                              ? unityVersions.first
                              : '';
                        });
                        debug('Refreshed Unity Versions\n');
                      },
                      icon: Icon(Icons.refresh),
                    ),
                  ],
                ),
                SizedBox(
                  height: 10,
                ),
                Container(
                  alignment: Alignment.centerLeft,
                  child: Text("Output:", style: TextStyle(fontSize: 20)),
                ),
                SizedBox(
                  height: 10,
                ),
                Expanded(
                  child: TextField(
                    scrollController: _scrollController,
                    controller: consoleController,
                    maxLines: null,
                    readOnly: true,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(10),
                    ),
                  ),
                ),
                Text(
                  "(c) 2023 flandolf. USE AT OWN RISK. CREATOR NOT RESPONSIBLE FOR ANY DAMAGES. THIS SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED. IN NO EVENT SHALL THE CREATOR BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. EDUCATIONAL PURPOSES ONLY.",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
