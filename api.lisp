(in-package #:lichat-admin)

(defun call-with-connection (function)
  (if postmodern:*database*
      (funcall function postmodern:*database*)
      (postmodern:with-connection (list (config :postgres :database)
                                        (config :postgres :username)
                                        (config :postgres :password)
                                        (config :postgres :host)
                                        :port (config :postgres :port)
                                        :pooled-p T)
        (funcall function postmodern:*database*))))

(defmacro with-connection ((&optional (connection (gensym "CONNECTION")) &rest args) &body body)
  `(call-with-connection (lambda (,connection)
                           (declare (ignorable ,connection))
                           ,@body)
                         ,@args))

(defun parse-time (time &optional (default (get-universal-time)))
  (etypecase time
    (integer time)
    (null default)
    (string (org.shirakumo.fuzzy-dates:parse time))))

(defmacro define-query (name args query &body body)
  (let ((statement (gensym "STATEMENT")))
    `(let ((,statement (postmodern:prepare ,query :rows)))
       (defun ,name ,args
         (with-connection ()
           (funcall ,statement ,@body))))))

(define-query list-channels (&key parent name)
    "SELECT * FROM \"lichat-channels\" 
     WHERE LOWER(\"name\") LIKE $1
     ORDER BY \"name\" ASC;"
  (format NIL "~(~@[~a.~]%~@[~a%~]~)" parent name))

(define-query list-members (channel)
    "SELECT * FROM \"lichat-users\" AS U
     LEFT JOIN \"lichat-channel-members\" AS M ON U.\"id\" = M.\"user\"
     WHERE M.\"channel\" = (SELECT \"id\" FROM \"lichat-channels\" WHERE LOWER(\"name\") = LOWER($1))
     ORDER BY U.\"name\" ASC;"
  channel)

(define-query list-users-with-registration (registration &key name connected-after connected-before created-after created-before)
    "SELECT * FROM \"lichat-users\"
     WHERE (\"registered\" = $1)
       AND ($2 IS NULL OR \"name\" LIKE $2)
       AND ($3 IS NULL OR ($3 <= \"last-connected\"))
       AND ($4 IS NULL OR (\"last-connected\" < 4))
       AND ($5 IS NULL OR ($5 <= \"created-on\"))
       AND ($6 IS NULL OR (\"created-on\" < 6))
     ORDER BY \"name\" ASC;"
  registration name
  connected-after connected-before
  created-after created-before)

(define-query list-users-without-registration (&key name connected-after connected-before created-after created-before)
    "SELECT * FROM \"lichat-users\"
     WHERE ($1 IS NULL OR \"name\" LIKE $1)
       AND ($2 IS NULL OR (\"last-connected\" < $2))
       AND ($3 IS NULL OR ($3 <= \"last-connected\"))
       AND ($4 IS NULL OR (\"created-on\" < $4))
       AND ($5 IS NULL OR ($6 <= \"created-on\"))
     ORDER BY \"name\" ASC;"
  name
  connected-after connected-before
  created-after created-before)

(defun list-users (&key name (registered-p NIL registration)
                        connected-after connected-before
                        created-after created-before)
  (if registration
      (list-users-with-registration registered-p :name name :connected-after connected-after :connected-before connected-before
                                                 :created-after created-after :created-before created-before)
      (list-users-with-registration :name name :connected-after connected-after :connected-before connected-before
                                    :created-after created-after :created-before created-before)))

(define-query list-connections-with-ssl (ssl &key user ip started-after started-before)
    "SELECT * FROM \"lichat-connections\" AS C
     LEFT JOIN \"lichat-users\" AS U ON C.\"user\" = U.\"id\"
     WHERE (C.\"ssl\" = $1)
       AND ($2 IS NULL OR (LOWER(U.\"name\") = LOWER($2)))
       AND ($3 IS NULL OR (C.\"ip\" = $3)
       AND ($4 IS NULL OR ($4 <= C.\"started-on\"))
       AND ($5 IS NULL OR (C.\"started-on\" < $5))
     ORDER BY U.\"name\" ASC, \"started-on\" ASC;"
  ssl user ip started-after started-before)

(define-query list-connections-without-ssl (&key user ip started-after started-before)
    "SELECT * FROM \"lichat-connections\" AS C
     LEFT JOIN \"lichat-users\" AS U ON C.\"user\" = U.\"id\"
     WHERE ($1 IS NULL OR (LOWER(U.\"name\") = LOWER($1)))
       AND ($2 IS NULL OR (C.\"ip\" = $2)
       AND ($3 IS NULL OR ($3 <= C.\"started-on\"))
       AND ($4 IS NULL OR (C.\"started-on\" < $4))
     ORDER BY U.\"name\" ASC, \"started-on\" ASC;"
  user ip started-after started-before)

(defun list-connections (&key user ip (ssl-p NIL ssl)
                              started-after started-before)
  (if ssl
      (list-connections-with-ssl ssl-p :user user :ip ip :started-after started-after :started-before started-before)
      (list-connections-without-ssl :user user :ip ip :started-after started-after :started-before started-before)))

(define-query iplog (&key ip action user after before)
    "SELECT * FROM \"lichat-ip-log\" AS I
     LEFT JOIN \"lichat-users\" AS U ON I.\"user\" = U.\"id\"
     WHERE ($1 IS NULL OR (I.\"ip\" = $1))
       AND ($2 IS NULL OR (I.\"action\" = $2))
       AND ($3 IS NULL OR (LOWER(U.\"name\") = LOWER($3)))
       AND ($4 IS NULL OR ($4 <= I.\"clock\"))
       AND ($5 IS NULL OR (I.\"clock\" < $5))
     ORDER BY \"clock\" DESC;"
  ip action user after before)

(define-query history (&key channel user after before text (limit 100) (offset 0))
    "SELECT H.*, U.\"name\" AS \"from\"
     FROM \"lichat-history\" AS H
          LEFT JOIN \"lichat-channels\" AS C ON C.\"id\" = H.\"channel\"
          LEFT JOIN \"lichat-users\" AS U ON U.\"id\" = H.\"user\"
     WHERE ($1 IS NULL OR LOWER(C.\"name\") = LOWER($1))
       AND ($2 IS NULL OR LOWER(U.\"name\") = LOWER($2))
       AND ($3 IS NULL OR $3 <= H.\"clock\")
       AND ($4 IS NULL OR H.\"clock\" < $4)
       AND ($5 IS NULL OR H.\"text\" ~ $5)
     ORDER BY H.\"clock\" ASC
     LIMIT $6
     OFFSET $7;"
  channel user after before text limit offset)
