import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class CroppingPage extends StatefulWidget {
  final String imagePath;
  const CroppingPage({super.key, required this.imagePath});

  @override
  _CroppingPageState createState() => _CroppingPageState();
}

class _CroppingPageState extends State<CroppingPage> {
  File? croppedImage;

  @override
  void initState() {
    super.initState();
    _cropImage();
  }

  Future<void> _cropImage() async {
    try {
      // Load the input image
      File inputImage = File(widget.imagePath);
      Uint8List imageBytes = await inputImage.readAsBytes();
      img.Image image = img.decodeImage(imageBytes)!; // Decode the image bytes

      // Get screen dimensions
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;

      // Calculate crop dimensions proportional to the screen
      final cropWidth = screenWidth.toInt();
      final cropHeight = (screenHeight / 2)
          .toInt(); // Cropping height to half the screen height
      final cropX = (image.width - cropWidth) ~/ 2;
      final cropY = (image.height - cropHeight) ~/ 2;

      // Crop the image using calculated dimensions
      img.Image cropped = img.copyCrop(image,
          x: cropX, y: cropY, width: cropWidth, height: cropHeight);

      // Get the application documents directory
      final appDir = await getApplicationDocumentsDirectory();
      File outputFile = File('${appDir.path}/cropped_image.jpg')
        ..writeAsBytesSync(img.encodeJpg(cropped)); // Save the cropped image

      // Update the state to display the cropped image
      setState(() {
        croppedImage = outputFile;
      });
    } catch (e) {
      print("Error cropping image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cropping image: $e')),
      );
    }
  }

  void _submitCroppedImage() {
    if (croppedImage != null) {
      // Handle image submission logic
      print("Cropped image path: ${croppedImage!.path}");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cropped image submitted successfully!')),
      );

      // Navigate or perform further actions
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No image to submit!')),
      );
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cropped Image")),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              croppedImage != null
                  ? FittedBox(
                      fit: BoxFit.contain,
                      // Ensures the image scales to fit within the screen while maintaining its aspect ratio
                      child: SizedBox(
                        width: MediaQuery.of(context)
                            .size
                            .width, // Set the width to fill the screen width
                        height: MediaQuery.of(context)
                            .size
                            .height, // Set the height to use the entire screen height
                        child: Image.file(
                          croppedImage!,
                          fit: BoxFit
                              .contain, // Ensure the image scales proportionally within the container
                        ),
                      ),
                    )
                  : const CircularProgressIndicator(),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _submitCroppedImage,
                child: const Text("Submit Cropped Image"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
