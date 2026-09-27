;;; run-canvas-tests.el --- Run Canvas tests in a GUI -*- lexical-binding: t; -*-

(require 'cl-lib)

(let* ((directory (file-name-directory (or load-file-name buffer-file-name)))
       (load-path (cons (expand-file-name ".." directory) load-path)))
  ;; GUI Emacs normally sends ERT progress only to the echo area.
  (cl-letf (((symbol-function 'message)
             (lambda (format-string &rest args)
               (when format-string
                 (let ((text (apply #'format-message format-string args)))
                   (princ (concat text "\n") #'external-debugging-output)
                   text)))))
    (condition-case err
        (progn
          (load (expand-file-name "embr-canvas-tests.el" directory) nil t)
          (let ((stats (ert-run-tests-batch '(tag native))))
            (kill-emacs (if (zerop (ert-stats-completed-unexpected stats))
                            0 1))))
      (error
       (message "Canvas test runner failed: %s" (error-message-string err))
       (kill-emacs 2)))))

;;; run-canvas-tests.el ends here
