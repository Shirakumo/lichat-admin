(asdf:defsystem #:lichat-admin
  :defsystem-depends-on (:radiance)
  :class "radiance:virtual-module"
  :serial T
  :version "0.0.0"
  :components ((:file "module")
               (:file "api")
               (:file "front"))
  :depends-on ((:interface :auth)
               :postmodern
               :r-clip
               :i-json
               :fuzzy-dates))
