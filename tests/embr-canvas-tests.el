;;; embr-canvas-tests.el --- Canvas compatibility tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'embr)

(defconst embr-test--directory
  (file-name-directory (or load-file-name buffer-file-name)))

(defun embr-test--jpeg ()
  "Return the binary JPEG fixture."
  (with-temp-buffer
    (set-buffer-multibyte nil)
    (insert-file-contents-literally
     (expand-file-name "fixtures/red.jpg" embr-test--directory))
    (buffer-string)))

(ert-deftest embr-canvas-rejects-unsuccessful-smoke-render ()
  "A loaded module must actually write pixels to pass detection."
  (cl-letf (((symbol-function 'image-type-available-p) (lambda (_) t))
            ((symbol-function 'embr--canvas-maybe-compile) #'ignore)
            ((symbol-function 'module-load) #'ignore)
            ((symbol-function 'embr-canvas-supported-p) (lambda () t))
            ((symbol-function 'embr-canvas-clear) (lambda (&rest _) nil)))
    (should-not (embr--canvas-available-p))))

(ert-deftest embr-canvas-preserves-compiler-diagnostics ()
  "A failed build must retain compiler output instead of losing it."
  (let ((directory (make-temp-file "embr-canvas-build-test-" t)))
    (unwind-protect
        (progn
          (make-directory (expand-file-name "native" directory))
          (with-temp-file (expand-file-name "native/embr-canvas.c" directory))
          (cl-letf (((symbol-function 'embr--canvas-source-dir)
                     (lambda () directory))
                    ((symbol-function 'call-process)
                     (lambda (_program _input destination _display &rest args)
                       (should (member (concat "EMACS="
                                               (expand-file-name
                                                invocation-name
                                                invocation-directory))
                                       args))
                       (with-current-buffer (car destination)
                         (insert "fatal error: emacs-module.h not found\n"))
                       2)))
            (should-error (embr--canvas-maybe-compile))
            (with-current-buffer "*embr-canvas-build*"
              (should (string-match-p "emacs-module.h not found"
                                      (buffer-string))))))
      (delete-directory directory t))))

(ert-deftest embr-canvas-native-render-and-resize ()
  "Create, clear, decode JPEGs and resize using the real Canvas API."
  :tags '(native)
  (should (display-graphic-p))
  (should (embr--canvas-available-p))
  (with-temp-buffer
    (let ((embr--canvas-image nil)
          (embr--canvas-resize-count 0)
          (jpeg (embr-test--jpeg)))
      (dolist (size '((4 . 4) (7 . 5) (1 . 1)))
        (let ((previous embr--canvas-image))
          (embr--canvas-resize (car size) (cdr size))
          (should-not (eq previous embr--canvas-image))
          (should (equal (image-size embr--canvas-image t) size))
          (should (equal (embr--canvas-dimensions embr--canvas-image) size))
          (should (embr-canvas-clear embr--canvas-image (car size) (cdr size)))
          (should (embr-canvas-blit-jpeg embr--canvas-image jpeg
                                         (car size) (cdr size) 1))
          (should-not (embr-canvas-blit-jpeg embr--canvas-image ""
                                             (car size) (cdr size) 2))
          (garbage-collect)
          (should (embr-canvas-clear embr--canvas-image
                                     (car size) (cdr size))))))))

(ert-deftest embr-canvas-native-fragmented-frame ()
  "Decode a socket frame split across packets into a larger canvas."
  :tags '(native)
  (should (display-graphic-p))
  (should (embr--canvas-available-p))
  (with-temp-buffer
    (let* ((embr--canvas-image (embr--canvas-create 5 3))
           (embr--canvas-recv-buf "")
           (embr--canvas-frame-count 0)
           (embr--canvas-error-count 0)
           (embr--canvas-stale-count 0)
           (embr--canvas-last-seq 0)
           (embr--canvas-stream-id 0)
           (jpeg (embr-test--jpeg))
           (header (apply #'unibyte-string
                          (cl-loop for value in (list 1 2 2 (length jpeg) 1)
                                   append (cl-loop for shift in '(0 8 16 24)
                                                   collect (logand 255
                                                                   (ash value (- shift)))))))
           (packet (concat header jpeg))
           (process (make-pipe-process :name "embr-canvas-test" :noquery t)))
      (unwind-protect
          (progn
            (process-put process 'embr-buffer (current-buffer))
            (embr--canvas-socket-filter process (substring packet 0 9))
            (should (= embr--canvas-frame-count 0))
            (embr--canvas-socket-filter process (substring packet 9 30))
            (should (= embr--canvas-frame-count 0))
            (embr--canvas-socket-filter process (substring packet 30))
            (should (= embr--canvas-frame-count 1))
            (should (= embr--canvas-error-count 0))
            (should (equal embr--canvas-recv-buf ""))
            (embr--canvas-socket-filter process packet)
            (should (= embr--canvas-frame-count 1))
            (should (= embr--canvas-stale-count 1)))
        (delete-process process)))))

;;; embr-canvas-tests.el ends here
