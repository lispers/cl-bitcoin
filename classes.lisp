
;;;; package information

(in-package #:cl-bitcoin)

;;; class creation macros to save us a bunch of typing

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun build-slot (classname slotname)
    "Creates a single slot to be used in a class definition. For now, initforms are not 
     supplied, initargs are the name of the slot, and accessors are the conventional 
     classname-slotname"
    (let ((accessor (intern (concatenate 'string (string classname) "-" (string slotname)))))
      (values
       (list slotname
	     :initform nil
	     :accessor accessor
	     :initarg (intern (string slotname) :keyword))
       accessor)))

  (defun build-instantiation-line (slotname)
    "Creates a line to be used in a make-* function of a custom btc class.
     This allows us to define btc classes in terms of their return values
     and automatically generate functions to create instances of those classes."
    (let ((slotkey (intern (string slotname) :keyword)))
      (list slotkey `(cdr (assoc ,slotkey result)))))
)
  

(defmacro defbtcclass (classname &rest slotnames)
  "Defines a subclass of btc-base with the given slotnames. Accessors for each class 
   defined with this macro are exported as part of the public cl-bitcoin API. Also 
   defines an internal function for creating instances of the defined class based on 
   the bitcoind JSON objects that are returned from the service"
  (let ((accessors ()) 
	(slots ()) 
	(fname (intern (concatenate 'string "MAKE-" (string classname))))
	(flines ()))
    (loop for slotname in slotnames do
	 (multiple-value-bind (slot accessor) (build-slot classname slotname)
	   (push slot slots)
	   (push accessor accessors))
	 (setf flines (append flines (build-instantiation-line slotname))))
    `(progn
       (eval-when (:compile-toplevel :load-toplevel :execute)
	 (export ',accessors 'cl-bitcoin))
       (defclass ,classname (btc-base)
	 ,slots)
       (defun ,fname (result err id)
	 (make-instance ',classname
			,@flines
			:err err
			:id id)))))

;;; classes used for bitcoind method responses - some of these are reused across multiple
;;; methods where applicable

;; base class - all of the methods return an error and an rpd-ic

(defclass btc-base ()
  ((err :initform nil :accessor btc-base-err :initarg :err)
  (id :initform nil :accessor btc-base-id :initarg :id)))

;; used for any method that has only a single result value

(defbtcclass btc-single result)

;; from here on the rest of the bitcoind methods require their own type

(defbtcclass btc-block hash confirmations size height version merkleroot tx
	     time nonce bits difficulty chainwork previousblockhash)

(defbtcclass btc-blocktemplate version previousblockhash transactions
	     coinbaseaux coinbasevalue target mintimemutable noncerange
	     sigoplimit sizelimit curtime bits height coinbasetxn
	     workid)

(defbtcclass btc-info version protocolversion walletversion balance blocks
	     timeoffset connections proxy difficulty keypoololdest
	     keypoolsize paytxfee errors)

(defbtcclass btc-mininginfo blocks currentblocksize currentblocktx difficulty
	     errors generate genproclimit hashespersec networkhashps
	     pooledtx testnet)

(defbtcclass btc-txoutset height bestblock transactions txouts 
	     bytes--serialized hash--serialized total--amount)

(defbtcclass btc-workinfo midstate data hash1 target)

(defbtcclass btc-sinceblock transactions lastblock)

  