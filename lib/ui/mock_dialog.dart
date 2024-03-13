import 'package:flutter/material.dart';

class MockDialog extends StatelessWidget {
  final String title;
  final String button1Title;
  final String button2Title;
  final Function button1Callback;
  final Function button2Callback;

  const MockDialog({
    super.key,
    required this.title,
    required this.button1Title,
    required this.button2Title,
    required this.button1Callback,
    required this.button2Callback,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0.0,
      insetPadding: const EdgeInsets.all(16.0),
      backgroundColor: Colors.transparent,
      child: _buildDialogContent(context),
    );
  }

  Widget _buildDialogContent(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              ElevatedButton(
                onPressed: () => button1Callback(),
                child: Text(button1Title),
              ),
              ElevatedButton(
                onPressed: () => button2Callback(),
                child: Text(button2Title),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
