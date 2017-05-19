/*
 * generated by Xtext 2.11.0
 */
package it.unica.tcs.validation

import it.unica.tcs.bitcoinTM.BitcoinTMPackage
import it.unica.tcs.bitcoinTM.Declaration
import it.unica.tcs.bitcoinTM.Input
import it.unica.tcs.bitcoinTM.KeyBody
import it.unica.tcs.bitcoinTM.KeyDeclaration
import it.unica.tcs.bitcoinTM.Script
import it.unica.tcs.bitcoinTM.SerialTxBody
import it.unica.tcs.bitcoinTM.Signature
import it.unica.tcs.bitcoinTM.UserDefinedTxBody
import it.unica.tcs.bitcoinTM.Versig
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.validation.Check

import static extension it.unica.tcs.validation.BitcoinJUtils.*
import it.unica.tcs.validation.BitcoinJUtils.ValidationResult

/**
 * This class contains custom validation rules. 
 *
 * See https://www.eclipse.org/Xtext/documentation/303_runtime_concepts.html#validation
 */
class BitcoinTMValidator extends AbstractBitcoinTMValidator {


	/*
	 * INFO
	 */	
	@Check
	def void checkSingleElementArray(UserDefinedTxBody tbody) {
		
		var inputs = tbody.inputs
		var outputs = tbody.outputs
		
		if (tbody.isMultiIn && inputs.size==1) {
			info("Single element arrays can be replaced by the element itself.",
				BitcoinTMPackage.Literals.USER_DEFINED_TX_BODY__INPUTS
			);	
		}
		
		if (tbody.isIsMultiOut && outputs.size==1) {
			info("Single element arrays can be replaced by the element itself.", 
				BitcoinTMPackage.Literals.USER_DEFINED_TX_BODY__OUTPUTS
			);	
		}
	}

	/*
	 * WARNING
	 */
	@Check
	def void checkIncompleteKey(KeyBody kbody){
		var pvt = kbody.pvt.value
		var pub = kbody.pub.value
		
		if (pvt == "_" && pub == "_") {
			warning("This key cannot be used anywhere.",
				kbody.eContainer,
				BitcoinTMPackage.Literals.KEY_DECLARATION__BODY
			);
		}		
	}
	
	@Check
	def void checkUnusedParameters(Script script){

		for (param : script.params) {
			var references = EcoreUtil.UsageCrossReferencer.find(param, param.eResource());
			
			if (references.size==0)
				warning("Unused variable '"+param.name+"'.", 
					param,
					BitcoinTMPackage.Literals.PARAMETER__NAME
				);			
		}
	}
	
	@Check
	def void checkVerSigDuplicatedKeys(Versig versig) {
		
		for(var i=0; i<versig.pubkeys.size-1; i++) {
			for(var j=i; j<versig.pubkeys.size; j++) {
				
				var k1 = versig.pubkeys.get(i)
				var k2 = versig.pubkeys.get(j)
				
				if (k1==k2) {
					warning("Duplicated public key.", versig, BitcoinTMPackage.Literals.VERSIG__PUBKEYS, i);
					warning("Duplicated public key.", versig,BitcoinTMPackage.Literals.VERSIG__PUBKEYS, j);
				}
			}
		}		
	}
	
	@Check
	def void checkEmptyLambda(Script script) {
		if (script.params.size==0)
			warning("This output could be redeemed without providing any arguments.",
				script.eContainer,
				BitcoinTMPackage.Literals.OUTPUT__SCRIPT
			);
	}
	
	/*
     * ERROR
     */
	
    @Check
	def void checkDeclarationNameIsUnique(Declaration t) {
		
		var root = EcoreUtil2.getRootContainer(t);
		for (other: EcoreUtil2.getAllContentsOfType(root, Declaration)){
			
			if (t!=other && t.getName.equals(other.name)) {
				error("Duplicated name '"+other.name+"'.", 
					BitcoinTMPackage.Literals.DECLARATION__NAME
				);
			}
		}
	} 
    	
	
	@Check
	def void checkVerSig(Versig versig) {
		
		if (versig.pubkeys.size>15) {
			error("Cannot verify more than 15 public keys.", 
				BitcoinTMPackage.Literals.VERSIG__PUBKEYS
			);
		}
		
		if (versig.signatures.size > versig.pubkeys.size) {
			error("The number of signatures cannot exceed the number of public keys.", 
				versig,
				BitcoinTMPackage.Literals.VERSIG__SIGNATURES
			);
		}
		
		for(var i=0; i<versig.pubkeys.size; i++) {
			var k = versig.pubkeys.get(i).body
			
			if (k.pvt.value===null && k.pub.value===null) {
				error("The referred public key is not declared and cannot be computed by the private one.", 
					versig,
					BitcoinTMPackage.Literals.VERSIG__PUBKEYS,
					i
				);
			}
		}		
	}
	
	@Check
	def void checkSign(Signature sig) {
		var k = sig.key.body
		
		if (k.pvt.value===null) {
			error("The referred private key is not declared.", 
				sig,
				BitcoinTMPackage.Literals.SIGNATURE__KEY
			);
		}
	}
	
	
		
	@Check
	def void checkKeyDeclaration(KeyDeclaration keyDecl) {
		
		var pvtKey = keyDecl.body.pvt.value;
		var pubKey = keyDecl.body.pub.value;
		
		var pvtErr = false;
		var pubErr = false;
		var ValidationResult validationResult;
		
		/*
		 * WiF format: 	[1 byte version][32 bytes key][1 byte compression (optional)][4 bytes checksum] 
		 * Length:		36 o 38 bytes (without/with compression)
		 */
		if (pvtKey!==null && pvtKey.length!=52) {
			error("Invalid key length.", 
				keyDecl.body.pvt,
				BitcoinTMPackage.Literals.PRIVATE_KEY__VALUE
			)
			pvtErr = true
		}
		
		/*
		 * WiF format: 	[1 byte version][20 bytes key][4 bytes checksum] 
		 * Length:		50 bytes
		 */
		if (pubKey!==null && pubKey.length!=34) {
			error("Invalid key length.", 
				keyDecl.body.pub,
				BitcoinTMPackage.Literals.PUBLIC_KEY__VALUE
			)
			pubErr = true
		}
		
		
		/*
		 * Check if the encoding is valid (like the checksum bytes)
		 */
		if (!pvtErr && pvtKey !== null && !(validationResult=pvtKey.isBase58WithChecksum).ok) {
			error('''Invalid encoding of the private key. The string must represent a valid bitcon address in WiF format. Details: «validationResult.message»''',
				keyDecl.body.pvt,
				BitcoinTMPackage.Literals.PRIVATE_KEY__VALUE
			)
			pvtErr = true
		}		
		
		if (!pubErr && pubKey !== null && !(validationResult=pubKey.isBase58WithChecksum).ok) {
			error('''Invalid encoding of the public key. The string must represent a valid bitcon address in WiF format. Details: «validationResult.message»''',
				keyDecl.body.pub,
				BitcoinTMPackage.Literals.PUBLIC_KEY__VALUE
			)
			pubErr = true
		}
		
				
		/*
		 * Check if the declarations reflect the network declaration
		 */
		if (!pvtErr && pvtKey !== null && !(validationResult=pvtKey.isValidPrivateKey(keyDecl.networkParams)).ok) {
			error('''The address it is not compatible with the network declaration (default is testnet). Details: «validationResult.message»''',
				keyDecl.body.pvt,
				BitcoinTMPackage.Literals.PRIVATE_KEY__VALUE
			)
			pvtErr = true
		}
		
		if (!pubErr && pubKey !== null && !(validationResult=pubKey.isValidPublicKey(keyDecl.networkParams)).ok) {
			error('''The address it is not compatible with the network declaration (default is testnet). Details: «validationResult.message»''',
				keyDecl.body.pub,
				BitcoinTMPackage.Literals.PUBLIC_KEY__VALUE
			)
			pubErr = true
		}
		
		
		/*
		 * Check if the declared keys are a valid pair
		 */
		if (!pvtErr && !pubErr && pubKey!==null && pvtKey!==null && !(validationResult=isValidKeyPair(pvtKey,pubKey,keyDecl.networkParams)).ok
		) {
			error("The given keys are not a valid pair. You can omit the public part (it will be derived).",
				BitcoinTMPackage.Literals.KEY_DECLARATION__BODY
			)
		}
	}
	
	
	@Check
	def void checkUniqueLambdaParameters(Script p) {
		
		for (var i=0; i<p.params.size-1; i++) {
			for (var j=1; j<p.params.size; j++) {
				if (p.params.get(i).name == p.params.get(j).name) {
					error(
						"Duplicate parameter name '"+p.params.get(j).name+"'.", 
						p.params.get(j),
						BitcoinTMPackage.Literals.PARAMETER__NAME, j
					);
				}
			}
		}
	}
	
	@Check
	def void checkInput(Input input) {
		
		/* 
		 * TODO: quando sarà possibile deserializzare le transazioni il check
		 * considerà anche questo caso 
		 */
		
        if (!(input.txRef.tx.body instanceof UserDefinedTxBody))
            return
		
		var inputTx = input.txRef.tx.body as UserDefinedTxBody		 
		var outputs = inputTx.outputs;
		
		if (input.txRef.idx>=outputs.size) {
			error("This input is pointing to an undefined output script.",
				input.txRef,
				BitcoinTMPackage.Literals.TRANSACTION_REFERENCE__IDX
			);
			return;
		}
				
		var outputIdx = input.txRef.idx
		var outputScript = outputs.get(outputIdx).script;
		
		var numOfExps = input.actual.exps.size
		
		var numOfParams = outputScript.params.size
		if (numOfExps!=numOfParams) {
			error(
				"The number of expressions does not match the number of parameters.",
				BitcoinTMPackage.Literals.INPUT__ACTUAL
			);
		}						
	}
	
	@Check
	def void checkInputsAreUnique(UserDefinedTxBody tbody) {
		
		for (var i=0; i<tbody.inputs.size-1; i++) {
			for (var j=1; j<tbody.inputs.size; j++) {
				
				var inputA = tbody.inputs.get(i)
				var inputB = tbody.inputs.get(j)
				
				if (inputA.txRef.tx==inputB.txRef.tx && inputA.txRef.idx==inputB.txRef.idx) {
					error(
						"You cannot redeem the output twice.",
						inputA,
						BitcoinTMPackage.Literals.INPUT__TX_REF
					);
				
					error(
						"You cannot redeem the output twice.",
						inputB,
						BitcoinTMPackage.Literals.INPUT__TX_REF
					);
				}
			}
		}
	}
	
	@Check
	def void checkSerialTransaction(SerialTxBody tx) {
		
		var ValidationResult validationResult;
        if (!(validationResult=tx.bytes.isValidTransaction(tx.networkParams)).ok) {
			error(
				'''The string does not represent a valid transaction. Details: «validationResult.message»''',
				BitcoinTMPackage.Literals.SERIAL_TX_BODY__BYTES
			);
		}
	}
	
}




