import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../drift/app_database.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

class BookSpine extends StatefulWidget {
  final Book book;
  final double width;
  final double height;

  const BookSpine({
    super.key,
    required this.book,
    required this.width,
    required this.height,
  });

  @override
  State<BookSpine> createState() => _BookSpineState();
}

class _BookSpineState extends State<BookSpine> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cover = widget.book.coverPath ?? '';

    return GestureDetector(
      onTap: () => context.go('/book/${widget.book.id}'),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.identity()
            ..translateByVector3(Vector3(0, _hover ? -8 : 0, 0)),
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _hover ? 0.4 : 0.25),
                  blurRadius: _hover ? 16 : 8,
                  offset: Offset(0, _hover ? 8 : 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(3, 0),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (cover.isNotEmpty)
                    Image.file(
                      File(cover),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  else
                    _placeholder(),

                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: widget.height * 0.3,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.15),
                            Colors.transparent
                          ],
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.3),
                            Colors.black.withValues(alpha: 0.1),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7)
                          ],
                        ),
                      ),
                      child: Text(
                        widget.book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                        ),
                      ),
                    ),
                  ),

                  if (_hover)
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.6),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    final idx = widget.book.title.hashCode % 6;
    final colors = [
      Colors.indigo[300]!,
      Colors.teal[400]!,
      Colors.amber[700]!,
      Colors.deepOrange[400]!,
      Colors.purple[400]!,
      Colors.green[600]!,
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors[idx],
            colors[idx].withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Center(
        child: Icon(Icons.book,
            size: widget.width * 0.4, color: Colors.white.withValues(alpha: 0.7)),
      ),
    );
  }
}
