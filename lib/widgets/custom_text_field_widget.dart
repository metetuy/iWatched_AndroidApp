import 'package:flutter/material.dart';

class CustomTextFieldWidget extends StatelessWidget {
  final TextEditingController? editingController;
  final IconData? iconData;
  final String? assetReference;
  final String? labelText;
  final bool? isObscure;

  const CustomTextFieldWidget({
    super.key,
    this.editingController,
    this.iconData,
    this.assetReference,
    this.labelText,
    this.isObscure,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: editingController,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: iconData != null
            ? Icon(iconData)
            : Padding(
                padding: EdgeInsets.all(8),
                child: Image.asset(assetReference.toString()),
              ),
        labelStyle: const TextStyle(
          fontSize: 18,
          color: Colors.white,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(
            color: Colors.grey,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(
            color: Colors.grey,
          ),
        ),
      ),
      obscureText: isObscure!,
    );
  }
}
