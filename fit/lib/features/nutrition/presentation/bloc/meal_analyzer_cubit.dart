import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/nutrition_analysis.dart';
import '../../domain/repositories/nutrition_repository.dart';

/// Progress of a meal analysis.
enum AnalyzerStatus { idle, analyzing, done }

/// Current analysis status and result.
class MealAnalyzerState extends Equatable {
  const MealAnalyzerState({this.status = AnalyzerStatus.idle, this.result});
  final AnalyzerStatus status;
  final NutritionAnalysis? result;

  @override
  List<Object?> get props => [status, result];
}

/// Drives the "Describe your meal" box: text → [NutritionAnalysis].
class MealAnalyzerCubit extends Cubit<MealAnalyzerState> {
  MealAnalyzerCubit(this._analyzer) : super(const MealAnalyzerState());
  final NutritionAnalysisRepository _analyzer;

  /// Whether Gemini can be used for foods the local database doesn't know.
  bool get aiEnabled => _analyzer.remoteAvailable;

  /// Runs the pipeline (never throws).
  Future<void> analyze(String text) async {
    if (text.trim().isEmpty) return;
    emit(const MealAnalyzerState(status: AnalyzerStatus.analyzing));
    final result = await _analyzer.analyze(text);
    emit(MealAnalyzerState(status: AnalyzerStatus.done, result: result));
  }

  /// Clears the current result.
  void reset() => emit(const MealAnalyzerState());
}
