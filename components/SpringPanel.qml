import QtQuick

// Spring dos paineis que deslizam (PopupBase.offsetScale, aba dos toasts):
// assenta rapido, sem quique.
SpringAnimation {
  spring: 6
  damping: 0.8
  epsilon: 0.001
}
