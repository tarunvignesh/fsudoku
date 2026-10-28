/// Respecting a request for less movement.
library;

import 'package:flutter/material.dart';

/// Returns [full], or zero when the platform asks for reduced motion.
///
/// On the web this follows `prefers-reduced-motion`, which people set because
/// movement makes them unwell -- not as a taste preference. Everything the
/// animations convey here is also conveyed by the state they animate between,
/// so collapsing them to zero loses nothing but the movement.
Duration motionOf(BuildContext context, Duration full) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : full;

/// Whether the platform has asked for reduced motion.
bool reduceMotionOf(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);
