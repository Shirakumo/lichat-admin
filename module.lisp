(in-package #:modularize-user)
(define-module #:lichat-admin
    (:use #:cl #:radiance)
  (:export)
  (:local-nicknames))
(in-package #:lichat-admin)

(define-trigger startup ()
  (defaulted-config "localhost" :postgres :host)
  (defaulted-config 5432 :postgres :port)
  (defaulted-config "lichat" :postgres :username)
  (defaulted-config "lichat" :postgres :password)
  (defaulted-config "lichat" :postgres :database))
