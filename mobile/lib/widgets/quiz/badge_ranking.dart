import 'package:flutter/material.dart';

class BadgeRanking extends StatelessWidget {
  final int rank;

  const BadgeRanking({
    super.key,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: rank == 1 ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: rank == 1 ? Colors.white : Colors.white24,
          width: 1.2,
        ),
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          color: rank == 1 ? Colors.black : Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
