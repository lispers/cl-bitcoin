;;;; package information

(in-package #:cl-bitcoin)

;;; main bitcoind connection functionality

;; global variables - these persist as long as cl-bitcoin is loaded
;; these can be reset or set by the user at any time - they are not const

(defvar *uri* "http://127.0.0.1:8332"
  "The uri that will be used to connect to the bitcoind server")

(defvar *username* "user"
  "The username that will be used for basic authentication when
   making requests to the bitcoind server")

(defvar *password* "password"
  "The password that will be used for basic authentication when
   making requests to the bitcoind server")

(defvar *rpc-id* 0
  "The id that will be used for identifying subsequent RPC requests
   made to the bitcoind server")

;; functions that deal with global variable management

(defun set-connection-parameters (&key (uri "http://127.0.0.1:8332")
				       (username "jordan")
				       (password "kingsparrow12"))
  (setf *uri* uri)
  (setf *username* username)
  (setf *password* password)
  (list :uri *uri* :username *username* :password *password*))

(defun reset-rpc-id () 
  (setf *rpc-id* 0))

;; functions that connect with the actual bitcoind server

(defun execute-bitcoind-method (uri username password method &rest paramlist)
  "Calls the bitcoind server to execute the given method with the supplied
   parameters. Attempting to call a method that does not exist will signal
   an error. Parameters passed into this function with nil values are ignored.
   The bitcoind server should handle defaults for us."
  (let ((auth (list username password))
	(params (make-array (length paramlist) :initial-contents paramlist)))
    (flexi-streams:octets-to-string
     (drakma:http-request uri
			  :method :post
			  :basic-authorization auth
			  :content (json:with-explicit-encoder (json:encode-json-plist-to-string
				    (list
				     "method" method
				     "id" (incf *rpc-id*)
				     "params" (remove nil params)
				     "jsonrpc" "1.0")))
			  :content-type "application/json"))))

(defmacro get-bitcoind-result (method &rest paramlist)
  "Executes the given method with the supplied parameters
   against the bitcoind server. The top-level configured values are used for
   connection parameters"
  `(let ((x (json:decode-json-from-string 
		   (execute-bitcoind-method 
		      *uri* *username* *password* 
		      (format nil "~(~a~)" (symbol-name ,method)) 
		      ,@paramlist))))
	      (parse-bitcoind-object x)))

(defun parse-bitcoind-object (btc-obj)
  "Parses the JSON object that comes back from the bitcoind server. The object
   structure depends on the data being passed back - results are either cons or
   alists, along with a possible error field and an id that will match the rpc-id
   that the request was sent with"
   (cond
     ((not (typep (cdar btc-obj) 'list))
      (values (list (first btc-obj)) (cdr (second btc-obj)) (cdr (third btc-obj))))
     (t
      (values (cdar btc-obj) (cdr (second btc-obj)) (cdr (third btc-obj))))))

;; user convenience macros

(defmacro with-connection-parameters (uri username password &rest body)
  "A convenience macro that allows execution of a bitcoind server method using
   temporary connection parameters. The given method is executed using the 
   supplied parameters (we don't need to gensym here because the user shouldn't
   be shadowing our connection parameters in the first place)"
  `(let ((*uri* ,uri) (*username* ,username) (*password* ,password) (*rpc-id* 1))
     ,@body))