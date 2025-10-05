import 'package:flutter/material.dart';

class SafeNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const SafeNetworkImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Return error widget if URL is null or empty
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildErrorWidget();
    }

    return Image.network(
      imageUrl!,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;

        return placeholder ??
            Container(
              width: width,
              height: height,
              color: Colors.grey[300],
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            );
      },
      errorBuilder: (context, error, stackTrace) {
        print('SafeNetworkImage error loading: $imageUrl');
        print('Error: $error');
        return _buildErrorWidget();
      },
    );
  }

  Widget _buildErrorWidget() {
    return errorWidget ??
        Container(
          width: width,
          height: height,
          color: Colors.grey[300],
          child: Icon(
            Icons.person,
            size: (width != null && height != null)
                ? (width! < height! ? width! * 0.5 : height! * 0.5)
                : 32,
            color: Colors.grey[600],
          ),
        );
  }
}
