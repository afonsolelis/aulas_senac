document.addEventListener('DOMContentLoaded', () => {
  const slides = document.querySelectorAll('.slide');
  const totalSlides = slides.length;
  let currentSlide = 1;

  const prevBtn = document.getElementById('prevBtn');
  const nextBtn = document.getElementById('nextBtn');
  const progressBar = document.getElementById('progressBar');
  const fullscreenBtn = document.getElementById('fullscreenBtn');
  const slideCounter = document.getElementById('slideCounter');

  // --- Core Navigation ---

  function updateProgress() {
    if (totalSlides <= 1) return;
    const progress = ((currentSlide - 1) / (totalSlides - 1)) * 100;
    if (progressBar) progressBar.style.width = `${progress}%`;
  }

  function showSlide(n) {
    if (n < 1 || n > totalSlides) return;

    currentSlide = n;

    // Hide all
    slides.forEach(s => s.classList.remove('active'));

    // Show target
    const targetSlide = document.getElementById(`slide-${n}`);
    if (targetSlide) {
      targetSlide.classList.add('active');
    }

    // Update buttons
    if (prevBtn) prevBtn.disabled = (currentSlide === 1);
    if (nextBtn) nextBtn.disabled = (currentSlide === totalSlides);

    updateProgress();

    if (slideCounter) {
      slideCounter.textContent = `${currentSlide} / ${totalSlides}`;
    }

    // Notifica listeners (usado pela camada de animações anime.js v4 — base-styles.css)
    window.dispatchEvent(new CustomEvent('slide-change', {
      detail: { index: currentSlide, slide: targetSlide, total: totalSlides }
    }));
  }

  function nextSlide() {
    if (currentSlide < totalSlides) {
      showSlide(currentSlide + 1);
    }
  }

  function prevSlide() {
    if (currentSlide > 1) {
      showSlide(currentSlide - 1);
    }
  }

  // --- Fullscreen Logic ---

  function toggleFullscreen() {
    if (!document.fullscreenElement) {
      document.documentElement.requestFullscreen().catch((err) => {
        console.error(`Error attempting to enable fullscreen: ${err.message} (${err.name})`);
      });
    } else {
      document.exitFullscreen();
    }
  }

  function updateFullscreenButtonIcon() {
    if (fullscreenBtn) {
      const icon = fullscreenBtn.querySelector('i');
      if (icon) {
        if (document.fullscreenElement) {
          icon.classList.remove('fa-expand');
          icon.classList.add('fa-compress');
        } else {
          icon.classList.remove('fa-compress');
          icon.classList.add('fa-expand');
        }
      }
    }
  }

  // --- Event Listeners ---

  if (prevBtn) prevBtn.addEventListener('click', prevSlide);
  if (nextBtn) nextBtn.addEventListener('click', nextSlide);

  if (fullscreenBtn) {
    fullscreenBtn.addEventListener('click', toggleFullscreen);
  }

  document.addEventListener('fullscreenchange', updateFullscreenButtonIcon);

  document.addEventListener('keydown', (event) => {
    if (event.key === "ArrowRight") nextSlide();
    if (event.key === "ArrowLeft") prevSlide();
    if (event.key === "f" || event.key === "F") toggleFullscreen();
  });

  // Expõe API de navegação (necessário para scripts/capture-slides.mjs e animMap por-slide)
  window.showSlide = showSlide;
  window.nextSlide = nextSlide;
  window.previousSlide = prevSlide;

  // Init (Ensure correct start)
  showSlide(1);
});
