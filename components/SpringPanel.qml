import QtQuick

// Paineis grandes que deslizam (popups, launcher, centro, toasts): o mesmo spring
// da abertura de janela no Hyprland (tokens.motion.window_in). O Qt integra em
// passos de 16 ms (v += (spring*d - damping*v)/mass; x += v*0,016), entao
// spring = k*0,016 e damping = c*0,016 com massa 1 sao a mesma fisica.
SpringAnimation {
  spring: Theme.motion.window_in.k * 0.016
  damping: Theme.motion.window_in.c * 0.016
  epsilon: 0.001
}
