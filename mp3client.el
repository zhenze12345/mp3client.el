;;; mp3client.el --- 

;; Copyright (C) 2012 Free Software Foundation, Inc.
;;
;; Author:  zhenzegu@gmail.com
;; Maintainer:  zhenzegu@gmail.com
;; Created: 25 Dec 2012
;; Version: 0.01
;; Keywords 

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

;;; Commentary:

;; An emacs client to control my simple mp3 server in
;; https://github.com/zhenze12345/mp3server.

;; Put this file into your load-path and the following into your ~/.emacs:
;;   (require 'mp3client)

;;; Code:
(eval-when-compile
  (require 'cl))

(defvar mp3-client-buffer-name "*mp3-client*"
  "Buffer name of mp3 client.")

(defvar mp3-client-process-name "mp3-client"
  "Process name of mp3 client.")

(defvar mp3-client-service-host "127.0.0.1"
  "Host of mp3 server.")

(defvar mp3-client-service-port 6600
  "Port of mp3 server.")

(defvar mp3-client-get-status-timer nil
  "Timer of mp3 client used to get status.")

(defvar mp3-client-mode-line-value ""
  "Value to show in the mode list.")

(defun mp3-client-sentinel (proc string)
  (message (concat mp3-client-process-name " " string))
  (if (string= string "connection broken by remote peer")
      (mp3-client-stop)))

(defun mp3-client-refresh-music-list (msg)
  "Refresh music list in buffer."
  (if (get-buffer mp3-client-buffer-name)
      (progn
        (mp3-client-buffer-set-writable)
        (mp3-client-clear-buffer)
        (let ((buffer (get-buffer mp3-client-buffer-name)))
          (save-excursion
            (set-buffer buffer)
            (let ((music-list
                   (split-string msg "\n")))
              (mapcar `(lambda (music)
                         (insert-text-button music
                                             'action `(lambda (button)
                                                        (mp3-client-send-message
                                                         (concat "select " (button-label button))))
                                             'follow-link 'mouse-face
                                             'help-echo "Play this music")
                         (insert "\n"))
                      music-list))))
        (mp3-client-buffer-set-readonly))))

(defun mp3-client-filter (proc msg)
  "How to deal with server message."
  (cond
   ((string-match "\\([^\s]+\n\\)+" msg)
    (mp3-client-refresh-music-list msg))
   ((string-match "\\([^\s\n]+ \\)\\{3\\}[^\s\n]+" msg)
    (mp3-client-update-mode-line msg))))

(defun mp3-client-clear-buffer ()
  "Clear the buffer of mp3 client."
  (let ((buffer (get-buffer mp3-client-buffer-name)))
    (if buffer
        (save-excursion
          (set-buffer buffer)
          (erase-buffer)))))

(defun mp3-client-update-mode-line (msg)
  "Update music status in mode line."
  (string-match "\\(play\\|stop\\|pause\\) \\(.*\\)\.mp3 \\([0-9.]+\\) \\([0-9.]+\\)" msg)
  (let ((status
         (substring msg
                    (match-beginning 1)
                    (match-end 1)))
        (music-name
         (substring msg
                    (match-beginning 2)
                    (match-end 2)))
        (passed-time
         (string-to-number
          (substring msg
                     (match-beginning 3)
                     (match-end 3))))
        (last-time
         (string-to-number
          (substring msg
                     (match-beginning 4)
                     (match-end 4))))
        total-time)
    (setf total-time (+ passed-time last-time))
    (setf mp3-client-mode-line-value
          (format " %s[%s] %.1f/%.1fs "
                  music-name
                  status
                  passed-time
                  total-time))))

(defun mp3-client-get-music-status ()
  "Get music status: play, pause or stop."
  (if (string-match
       "\\[\\(.*\\)\\]"
       mp3-client-mode-line-value)
      (substring mp3-client-mode-line-value
                 (match-beginning 1)
                 (match-end 1))
    nil))

(defun mp3-client-network-client-start ()
  "Start network work of mp3 client."
  (make-network-process
   :name mp3-client-process-name
   :buffer mp3-client-buffer-name
   :family 'ipv4
   :host mp3-client-service-host
   :service mp3-client-service-port
   :sentinel 'mp3-client-sentinel
   :filter 'mp3-client-filter))

(defun mp3-client-buffer-set-readonly-status (value)
  (let ((buffer (get-buffer mp3-client-buffer-name)))
    (if buffer
        (save-excursion
          (set-buffer buffer)
          (setf buffer-read-only value)))))

(defun mp3-client-buffer-set-readonly ()
  "Set readonly to the buffer of mp3 client."
  (mp3-client-buffer-set-readonly-status t))

(defun mp3-client-buffer-set-writable ()
  "Set writable to the buffer of mp3 client."
  (mp3-client-buffer-set-readonly-status nil))

(defun mp3-client-fetch-music-list ()
  "Fetch music list from mp3 server."
  (interactive)
  (mp3-client-send-message "list"))

(defun mp3-client-next-music ()
  "Play next music from mp3 server."
  (interactive)
  (mp3-client-send-message "next"))

(defun mp3-client-restart-music ()
  "Restart this music from mp3 server."
  (interactive)
  (mp3-client-send-message "again"))

(defun mp3-client-play-music ()
  "Play music from mp3 server."
  (interactive)
  (mp3-client-send-message "play"))

(defun mp3-client-pause-music ()
  "Pause music from mp3 server."
  (interactive)
  (mp3-client-send-message "pause"))

(defun mp3-client-stop-music ()
  "Stop music from mp3 server."
  (interactive)
  (mp3-client-send-message "stop"))

(defun mp3-client-seek-+3sec ()
  (interactive)
  (let ((music-time (mp3-client-get-current-music-time)))
    (if music-time
        (mp3-client-send-message
         (concat "seek "
                 (number-to-string
                  (+ music-time 3)))))))

(defun mp3-client-seek--3sec ()
  (interactive)
  (let ((music-time (mp3-client-get-current-music-time)))
    (if music-time
        (mp3-client-send-message
         (concat "seek "
                 (number-to-string
                  (- music-time 3)))))))

(defun mp3-client-get-current-music-time ()
  "Get the current time of music."
  (if (string-match
       " .* \\([0-9.]+\\)/[0-9.]+s "
       mp3-client-mode-line-value)
      (string-to-number
       (substring mp3-client-mode-line-value
                  (match-beginning 1)
                  (match-end 1)))
    nil))

(defun mp3-client-send-message (message)
  "Send message to mp3 server."
  (let ((proc (get-process mp3-client-process-name)))
    (if proc
        (process-send-string proc message))))

(defun mp3-client-add-mode-line ()
  "add music status to mode line."
  (setf mode-line-format
        (append mode-line-format '(mp3-client-mode-line-value)))
  (setq-default mode-line-format mode-line-format))

(defun mp3-client-get-status-start-timer (start-time)
  "Turn on the timer to get music status."
  (setf mp3-client-get-status-timer
        (run-at-time start-time 0.5
                     `(lambda ()
                        (mp3-client-send-message "current")))))

(defun mp3-client-start ()
  "Start mp3 client."
  (interactive)
  (let ((proc (get-process mp3-client-process-name)))
    (if (and
         (not proc)
         (mp3-client-network-client-start))
        (progn
          (mp3-client-buffer-set-readonly)
          (mp3-client-fetch-music-list)
          (mp3-client-add-mode-line)
          (mp3-client-get-status-start-timer "1 sec")
          t)
      nil)))

(defun mp3-client-stop ()
  "Stop mp3 client."
  (interactive)
  (if mp3-client-get-status-timer
      (progn
        (cancel-timer mp3-client-get-status-timer)
        (setf mp3-client-get-status-timer)))
  (setf mode-line-format
        (remove-if `(lambda (x)
                      (equal x 'mp3-client-mode-line-value))
                   mode-line-format))
  (setq-default mode-line-format mode-line-format)
  (let ((proc (get-process mp3-client-process-name))
        (buffer (get-buffer mp3-client-buffer-name)))
    (if proc
        (delete-process proc))
    (if buffer
        (kill-buffer buffer))))

(defun mp3-client-play-or-pause ()
  "play or pause music"
  (interactive)
  (let ((status (mp3-client-get-music-status)))
    (cond ((string= status "play")
           (mp3-client-pause-music))
          ((or (string= status "pause")
               (string= status "stop"))
           (mp3-client-play-music)))))

(provide 'mp3client)
;;; mp3client.el ends here
