import QtQuick

// Coisas pequenas (largura de pill, barra do OSD, workspace ativo): spring
// spatial_fast do M3 Expressive, rapido e passando um pouco do ponto.
// Conversao para o Qt: ver SpringPanel.
SpringAnimation {
  spring: Theme.motion.spatial_fast.k * 0.016
  damping: Theme.motion.spatial_fast.c * 0.016
  epsilon: 0.5
}
