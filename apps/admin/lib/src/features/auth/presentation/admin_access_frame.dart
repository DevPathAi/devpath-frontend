import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

/// Shared, wordmark-only frame for Admin authentication and access states.
///
/// The approved brand mark asset is not present, so this intentionally avoids
/// synthesizing a placeholder mark.
class AdminAccessFrame extends StatelessWidget {
  const AdminAccessFrame({
    super.key,
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(DpSpacing.lg),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - DpSpacing.xxl).clamp(
                  0.0,
                  double.infinity,
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(DpSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                            label: 'Leva 운영 콘솔',
                            child: ExcludeSemantics(
                              child: Wrap(
                                spacing: DpSpacing.xs,
                                runSpacing: DpSpacing.xs,
                                crossAxisAlignment: WrapCrossAlignment.end,
                                children: [
                                  Text('Leva', style: text.headlineSmall),
                                  Text('운영 콘솔', style: text.labelLarge),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: DpSpacing.xl),
                          Semantics(
                            header: true,
                            label: title,
                            child: ExcludeSemantics(
                              child: Text(title, style: text.headlineSmall),
                            ),
                          ),
                          const SizedBox(height: DpSpacing.sm),
                          Text(description, style: text.bodyMedium),
                          const SizedBox(height: DpSpacing.xl),
                          child,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
