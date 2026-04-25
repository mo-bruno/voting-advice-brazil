import 'package:flutter/material.dart';

class ImagemPolitica extends StatelessWidget {
  final String? url;
  final String? urlSecundaria;
  final String fallbackText;
  final double size;
  final bool circular;
  final BoxFit fit;

  const ImagemPolitica({
    super.key,
    required this.url,
    this.urlSecundaria,
    required this.fallbackText,
    required this.size,
    this.circular = true,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final radius = circular ? size / 2 : 12.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        color: const Color(0xFF111111),
        child: _ImagemRemota(
          url: url,
          urlSecundaria: urlSecundaria,
          fallbackText: fallbackText,
          fit: fit,
        ),
      ),
    );
  }
}

class _ImagemRemota extends StatelessWidget {
  final String? url;
  final String? urlSecundaria;
  final String fallbackText;
  final BoxFit fit;

  const _ImagemRemota({
    required this.url,
    required this.urlSecundaria,
    required this.fallbackText,
    required this.fit,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return _imagemSecundariaOuFallback();
    }

    return Image.network(
      url!,
      fit: fit,
      errorBuilder: (_, __, ___) => _imagemSecundariaOuFallback(),
    );
  }

  Widget _imagemSecundariaOuFallback() {
    if (urlSecundaria == null || urlSecundaria!.isEmpty) {
      return _FallbackImagem(texto: fallbackText);
    }

    return Image.network(
      urlSecundaria!,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _FallbackImagem(texto: fallbackText),
    );
  }
}

class _FallbackImagem extends StatelessWidget {
  final String texto;

  const _FallbackImagem({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        texto.isEmpty
            ? '?'
            : (texto.length <= 3 ? texto : texto.substring(0, 3)),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
