import 'package:flutter/material.dart';
import '../../shared/models/thesis.dart';

class WeightingController extends ChangeNotifier {
  final List<Thesis> theses;

  WeightingController({required this.theses});

  void toggleWeight(int index) {
    theses[index].doubleWeight = !theses[index].doubleWeight;
    notifyListeners();
  }

  int get doubleWeightCount => theses.where((t) => t.doubleWeight).length;
}
