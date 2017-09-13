/*
 * generated by Xtext 2.11.0
 */
package it.unica.tcs.validation

import com.google.inject.Inject
import it.unica.tcs.bitcoinTM.AbsoluteTime
import it.unica.tcs.bitcoinTM.AfterTimeLock
import it.unica.tcs.bitcoinTM.ArithmeticSigned
import it.unica.tcs.bitcoinTM.BitcoinTMPackage
import it.unica.tcs.bitcoinTM.BitcoinValue
import it.unica.tcs.bitcoinTM.Declaration
import it.unica.tcs.bitcoinTM.Expression
import it.unica.tcs.bitcoinTM.Hash
import it.unica.tcs.bitcoinTM.Import
import it.unica.tcs.bitcoinTM.Input
import it.unica.tcs.bitcoinTM.KeyBody
import it.unica.tcs.bitcoinTM.KeyDeclaration
import it.unica.tcs.bitcoinTM.Literal
import it.unica.tcs.bitcoinTM.Modifier
import it.unica.tcs.bitcoinTM.Output
import it.unica.tcs.bitcoinTM.PackageDeclaration
import it.unica.tcs.bitcoinTM.RelativeTime
import it.unica.tcs.bitcoinTM.Signature
import it.unica.tcs.bitcoinTM.TransactionDeclaration
import it.unica.tcs.bitcoinTM.TransactionReference
import it.unica.tcs.bitcoinTM.Versig
import it.unica.tcs.compiler.CompileException
import it.unica.tcs.compiler.TransactionCompiler
import it.unica.tcs.utils.ASTUtils
import it.unica.tcs.utils.BitcoinJUtils.ValidationResult
import it.unica.tcs.xsemantics.BitcoinTMTypeSystem
import java.util.HashSet
import java.util.Set
import org.bitcoinj.core.ScriptException
import org.bitcoinj.core.Transaction
import org.bitcoinj.core.Utils
import org.bitcoinj.script.Script
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.naming.IQualifiedNameConverter
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.resource.IContainer
import org.eclipse.xtext.resource.IEObjectDescription
import org.eclipse.xtext.resource.IResourceDescription
import org.eclipse.xtext.resource.IResourceDescriptions
import org.eclipse.xtext.resource.impl.ResourceDescriptionsProvider
import org.eclipse.xtext.validation.Check
import org.eclipse.xtext.validation.ValidationMessageAcceptor

import static org.bitcoinj.script.Script.*

import static extension it.unica.tcs.utils.ASTUtils.*
import static extension it.unica.tcs.utils.BitcoinJUtils.*
import it.unica.tcs.bitcoinTM.SignatureType
import it.unica.tcs.bitcoinTM.UserTransactionDeclaration
import it.unica.tcs.bitcoinTM.SerialTransactionDeclaration
import it.unica.tcs.bitcoinTM.TransactionBody
import it.unica.tcs.bitcoinTM.ProcessDeclaration
import it.unica.tcs.bitcoinTM.ParticipantDeclaration

/**
 * This class contains custom validation rules. 
 *
 * See https://www.eclipse.org/Xtext/documentation/303_runtime_concepts.html#validation
 */
//@ComposedChecks(
//	validators=ImportUriValidator
//)
class BitcoinTMValidator extends AbstractBitcoinTMValidator {

	@Inject private extension IQualifiedNameConverter qualifiedNameConverter
    @Inject private extension BitcoinTMTypeSystem typeSystem
    @Inject private extension ASTUtils astUtils
    @Inject private extension TransactionCompiler txCompiler
    @Inject	private ResourceDescriptionsProvider resourceDescriptionsProvider;
	@Inject	private IContainer.Manager containerManager;

	/*
	 * INFO
	 */	
	@Check
	def void checkSingleElementArray(UserTransactionDeclaration tx) {
		var tbody = tx.body
		var inputs = tbody.inputs
		var outputs = tbody.outputs
		
		if (tbody.isMultiIn && inputs.size==1) {
			info("Single element arrays can be replaced by the element itself.",
				BitcoinTMPackage.Literals.TRANSACTION_BODY__INPUTS
			);	
		}
		
		if (tbody.isIsMultiOut && outputs.size==1) {
			info("Single element arrays can be replaced by the element itself.", 
				BitcoinTMPackage.Literals.TRANSACTION_BODY__OUTPUTS
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
	def void checkUnusedParameters(it.unica.tcs.bitcoinTM.Script script){

		for (param : script.params) {
			var references = EcoreUtil.UsageCrossReferencer.find(param, param.eResource());
			// var references = EcoreUtil2.getAllContentsOfType(script.exp, VariableReference).filter[v|v.ref==p].size 
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
			for(var j=i+1; j<versig.pubkeys.size; j++) {
				
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
	def void checkSignatureModifiers(Signature signature) {
		
		var input = EcoreUtil2.getContainerOfType(signature, Input);
		for (other: EcoreUtil2.getAllContentsOfType(input, Signature)){
			
			if (signature!=other && signature.modifier.restrictedBy(other.modifier)) {
				warning('''This signature modifier is nullified by another one.''',
					signature,
					BitcoinTMPackage.Literals.SIGNATURE__MODIFIER
				);
				warning('''This signature modifier is nullifying another one.''',
					other, 
					BitcoinTMPackage.Literals.SIGNATURE__MODIFIER
				);
			}
		}	
	}
	
	def private boolean restrictedBy(Modifier _this, Modifier other) {
		false;
	}
	
	@Check
	def void checkEmptyLambda(it.unica.tcs.bitcoinTM.Script script) {
		if (script.params.size==0 && !script.isOpReturn) {
		    
		    if (script.eContainer instanceof Output)
    			warning("This output could be redeemed without providing any arguments.",
    				script.eContainer,
    				BitcoinTMPackage.Literals.OUTPUT__SCRIPT
    			);
    		
    		if (script.eContainer instanceof Input)
                warning("This output could be redeemed without providing any arguments.",
                    script.eContainer,
                    BitcoinTMPackage.Literals.INPUT__REDEEM_SCRIPT
                );
		}
	}
	
	
	@Check
	def void checkInterpretExp(Expression exp) {
		
//		println(":::::::::::::::::::::::::::::::::::::::")
//		println('''exp:              «exp»''')
//		println('''context:          «context.keySet.filter(Expression)»''')
//		println('''contains paremt:  «context.containsKey(exp.eContainer)»''')
//		println()		
		
		if (context.containsKey(exp.eContainer) 
			|| exp instanceof Literal
			|| exp instanceof ArithmeticSigned
			|| exp.eContainer instanceof BitcoinValue
		){
			// your parent can be simplified, so you are too
			context.put(exp, exp)
			return
		}
		
		
//		var resSimplify = exp.simplify					// simplify && || + - 
		var resInterpret = exp.simplifySafe.interpret	// simplify if possible, then interpret
		
		var container = exp.eContainer
		var index = 
			if (container instanceof Input) {
				container.exps.indexOf(exp)
			}
			else ValidationMessageAcceptor.INSIGNIFICANT_INDEX
		
		if (!resInterpret.failed /* || !resSimplify.failed*/) {
			
			// the expression can be simplified. Store it within the context such that sub-expression will skip this check
			context.put(exp, exp)
		
			var compilationResult = 
				switch (resInterpret.first) {
					byte[]: (exp as Hash).type+":"+Utils.HEX.encode(resInterpret.first as byte[])
					String: '''"«resInterpret.first»"''' 
					default: resInterpret.first.toString
				} 
		
			warning('''This expression can be simplified. It will be compiled as «compilationResult» ''',
				exp.eContainer,
				exp.eContainmentFeature,
				index
			);
			
		}
	}

	
	
	/*
     * ERROR
     */
	
	@Check
	def void checkPackageDuplicate(PackageDeclaration pkg) {
		var Set<QualifiedName> names = new HashSet();
		var IResourceDescriptions resourceDescriptions = resourceDescriptionsProvider.getResourceDescriptions(pkg.eResource());
		var IResourceDescription resourceDescription = resourceDescriptions.getResourceDescription(pkg.eResource().getURI());
		for (IContainer c : containerManager.getVisibleContainers(resourceDescription, resourceDescriptions)) {
			for (IEObjectDescription od : c.getExportedObjectsByType(BitcoinTMPackage.Literals.PACKAGE_DECLARATION)) {
				if (!names.add(od.getQualifiedName())) {
					error(
						"Duplicated package name", 
						BitcoinTMPackage.Literals.PACKAGE_DECLARATION__NAME
					);
				}
			}
		}
	}
	
	@Check
	def void checkImport(Import imp) {
		
		var packageName = (imp.eContainer as PackageDeclaration).name.toQualifiedName
		var importedPackage = imp.importedNamespace.toQualifiedName
		
		if (packageName.equals(importedPackage.skipLast(1))) {
			error(
				'''The import «importedPackage» refers to this package declaration''', 
				BitcoinTMPackage.Literals.IMPORT__IMPORTED_NAMESPACE
			);
			return
		}
		
		var Set<QualifiedName> names = new HashSet();
		var IResourceDescriptions resourceDescriptions = resourceDescriptionsProvider.getResourceDescriptions(imp.eResource());
		var IResourceDescription resourceDescription = resourceDescriptions.getResourceDescription(imp.eResource().getURI());
		
		for (IContainer c : containerManager.getVisibleContainers(resourceDescription, resourceDescriptions)) {
			for (IEObjectDescription od : c.getExportedObjectsByType(BitcoinTMPackage.Literals.PACKAGE_DECLARATION)) {
				names.add(od.qualifiedName.append("*"))
			}
			for (IEObjectDescription od : c.getExportedObjectsByType(BitcoinTMPackage.Literals.TRANSACTION_DECLARATION)) {
				names.add(od.qualifiedName)
			}
		}
		
		if (!names.contains(importedPackage)) {
			error(
				'''The import «importedPackage» cannot be resolved''', 
				BitcoinTMPackage.Literals.IMPORT__IMPORTED_NAMESPACE
			);
		}
	}
	
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
	def void checkProcessDeclarationNameIsUnique(ProcessDeclaration t) {
		
		var container = EcoreUtil2.getContainerOfType(t, ParticipantDeclaration);
		for (other: EcoreUtil2.getAllContentsOfType(container, ProcessDeclaration)){
			
			if (t!=other && t.getName.equals(other.name)) {
				error("Duplicated name '"+other.name+"'.", 
					BitcoinTMPackage.Literals.PROCESS_DECLARATION__NAME
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
			
			if (k.pvt.value===null) {
				error("The public key cannot be computed without the private key.", 
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
	def void checkOutputWithoutSignatures(Output output) {
		var signs = EcoreUtil2.getAllContentsOfType(output, Signature);
			
		signs.forEach[s|
			error("Signatures are not allowed within output scripts.", 
				s.eContainer,
				s.eContainmentFeature
			);
		]	
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
	def void checkUniqueLambdaParameters(it.unica.tcs.bitcoinTM.Script p) {
		
		for (var i=0; i<p.params.size-1; i++) {
			for (var j=i+1; j<p.params.size; j++) {
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
	def void checkSerialTransaction(SerialTransactionDeclaration tx) {
		
		var ValidationResult validationResult;
        if (!(validationResult=tx.bytes.isValidTransaction(tx.networkParams)).ok) {
			error(
				'''The string does not represent a valid transaction. Details: «validationResult.message»''',
				BitcoinTMPackage.Literals.SERIAL_TRANSACTION_DECLARATION__BYTES
			);
		}
	}
	
	@Check
	def void checkUserDefinedTx(UserTransactionDeclaration tx) {

		var tbody = tx.body		
		var hasError = false;
//		println('''--- transaction «(tbody.eContainer as TransactionDeclaration).name»---''')
		
		/*
		 * Check transaction parameters
		 */
		for (param: tx.params) {
//			var param = tbody.params.get(i)
			if (param.paramType instanceof SignatureType) {
				error(
                    "Signature parameters are not allowed yet.",
                    param,
                    BitcoinTMPackage.Literals.PARAMETER__NAME
                );
			    hasError = hasError || true
			}
		}
		
		
		if(hasError) return;  // interrupt the check
		
		/*
		 * Verify that inputs are valid
		 */
		
		for (input: tbody.inputs) {
			var valid = 
				input.isPlaceholder || (
					input.checkInputTransactionParams && 
					input.checkInputIndex && 
					input.checkInputExpressions
				)
				
		    hasError = hasError || !valid
//		    println('''input «input»''')
//		    println('''hasError «hasError»''')
		}
		
		if(hasError) return;  // interrupt the check
		
		/*
		 * pairwise verify that inputs are unique
		 */
		for (var i=0; i<tbody.inputs.size-1; i++) {
			for (var j=i+1; j<tbody.inputs.size; j++) {
				
				var inputA = tbody.inputs.get(i)
				var inputB = tbody.inputs.get(j)
				
				// these checks need to be executed in this order
				var areValid = checkInputsAreUnique(inputA, inputB)
				
				hasError = hasError || !areValid
			}
		}
		
		if(hasError) return;  // interrupt the check

		/*
		 * Verify that the fees are positive
		 */
        hasError = !tx.checkFee
        
        if(hasError) return;  // interrupt the check
        
        /*
         * Verify that the input correctly spends the output
         */
        hasError = tx.correctlySpendsOutput
	}

    def boolean checkInputTransactionParams(Input input) {

        var inputTx = input.txRef.tx
        if (inputTx instanceof UserTransactionDeclaration) {
            
            if (inputTx.params.size!=input.txRef.actualParams.size) {
	            error(
                    "The number of expressions does not match the number of parameters.",
                    input.txRef,
                    BitcoinTMPackage.Literals.TRANSACTION_REFERENCE__ACTUAL_PARAMS
                );
                return false
            }
        }
        
        return true
    }
	
	def boolean checkInputIndex(Input input) {

        var outIndex = input.outpoint
        var int numOfOutputs
        var inputTx = input.txRef.tx
        
        if (inputTx instanceof SerialTransactionDeclaration) {
            numOfOutputs = inputTx.compileTransaction.outputsSize
        }
        else if (inputTx instanceof UserTransactionDeclaration){
            numOfOutputs = inputTx.body.outputs.size
        }
        
        if (outIndex>=numOfOutputs) {
            error("This input is pointing to an undefined output script.",
                input.txRef,
                BitcoinTMPackage.Literals.INPUT__OUTPOINT
            );
            return false
        }
        
        return true
    }
    
    def boolean checkInputExpressions(Input input) {
        var inputTx = input.txRef.tx
        var outputIdx = input.outpoint
        var lastExp = input.exps.get(input.exps.size-1)
		
		if (inputTx instanceof UserTransactionDeclaration) {
            var outputScript = inputTx.body.outputs.get(outputIdx).script;
            
            var numOfExps = input.exps.size
            var numOfParams = outputScript.params.size
            
            if (numOfExps!=numOfParams) {
                error(
                    "The number of expressions does not match the number of parameters.",
                    input,
                    BitcoinTMPackage.Literals.INPUT__EXPS
                );
                return false
            }
            
            if (lastExp instanceof Script) {
                error(
                    "You must not specify the redeem script when referring to a user-defined transaction.",
                    lastExp,
                    BitcoinTMPackage.Literals.INPUT__EXPS,
                    input.exps.size-1
                );
                return false
            }
            
            return true
        }
        else {
            
            var refTx = input.txRef.tx.compileTransaction.toTransaction(input.networkParams)
                        
            if (refTx.getOutput(outputIdx).scriptPubKey.payToScriptHash &&
                lastExp instanceof Script
            ) {
                error(
                    "You must specify the redeem script when referring to a P2SH output of a serialized transaction.",
                    input,
                    BitcoinTMPackage.Literals.INPUT__EXPS,
                    input.exps.size-1
                );
                return false
            }
            
            if (!refTx.getOutput(outputIdx).scriptPubKey.payToScriptHash &&
                lastExp instanceof Script
            ) {
                error(
                    "The pointed output is not a P2SH output. You must not specify the redeem script.",
                    input,
                    BitcoinTMPackage.Literals.INPUT__EXPS,
                    input.exps.size-1
                );
                return false
            }
        }
        
        return true
    }
    
    def boolean checkInputsAreUnique(Input inputA, Input inputB) {
        if (inputA.txRef.tx==inputB.txRef.tx && 
            inputA.outpoint==inputB.outpoint
        ) {
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
            return false
        }
        return true
    }
	
    def boolean checkFee(UserTransactionDeclaration tx) {
        
        var amount = 0L
        
        for (in : tx.body.inputs) {
        	var inputTx = in.txRef.tx
            if (inputTx instanceof UserTransactionDeclaration) {
                var index = in.outpoint
                var output = inputTx.body.outputs.get(index) 
                var value = output.value.exp.interpret.first as Integer
                amount+=value
            }
            else if (inputTx instanceof SerialTransactionDeclaration){
                var index = in.outpoint
                var txbody = inputTx.bytes
                var value = txbody.getOutputAmount(tx.networkParams, index)
                amount+=value
            }
        }
        
        for (output : tx.body.outputs) {
            var value = output.value.exp.interpret.first as Integer
            amount-=value
        }

        if (amount==0) {
            warning("Fees are zero.",
                tx,
                BitcoinTMPackage.Literals.USER_TRANSACTION_DECLARATION__BODY
            );
        }
        
        if (amount<0) {
            error("The transaction spends more than expected.",
                tx,
                BitcoinTMPackage.Literals.USER_TRANSACTION_DECLARATION__BODY
            );
            return false;
        }
        
        return true;
    }
    
    def boolean correctlySpendsOutput(UserTransactionDeclaration tx) {
        var tbody = tx.body
        
        if (tx.params.size>0) {
        	// TODO: checks where the free variables appear
        	info(
				'''Cannot check if these inputs are correctly spending their outputs''',
				tbody,
				BitcoinTMPackage.Literals.TRANSACTION_BODY__INPUTS						
			)
			return true
        }
        
        for (var i=0; i<tbody.inputs.size; i++) {

            var input = tbody.inputs.get(i)
            var Script inScript
            var Script outScript
            
            try {
				var txBuilder = tx.compileTransaction
				var txJ = txBuilder.toTransaction(tbody.networkParams)
				
				try {
					txJ.verify();
				}
				catch (Exception e) {
					warning(
						'''
						The transaction is not valid.
						
						Details: «e.message»
						''',
						tbody.eContainer,
						tbody.eContainingFeature						
					)
					return false
				}

                inScript = txJ.getInput(i).scriptSig
                outScript = txJ.getInput(i).outpoint.connectedOutput.scriptPubKey
                inScript.correctlySpends(
	                    txJ, 
	                    i, 
	                    outScript, 
	                    ALL_VERIFY_FLAGS
	                )
                
//              	println("input "+inScript+" correctly redeem output "+outScript)
//                
//                tx.body.outputs.forEach[out|
//                	println('''out[«out.index»]: «out.scriptPubKey.toString»''')
//                ]
                
            } catch(ScriptException e) {

                warning(
                    '''
                    This input does not redeem the specified output script. 
                    
                    Details: «e.message»
                    
                    INPUT:   «inScript»
                    OUTPUT:  «outScript»
                    «IF outScript.isPayToScriptHash»
                    REDEEM SCRIPT:  «new Script(inScript.chunks.get(inScript.chunks.size-1).data)»
                    REDEEM SCRIPT HASH:  «Utils.HEX.encode(Utils.sha256hash160(new Script(inScript.chunks.get(inScript.chunks.size-1).data).program))»
					«ENDIF»''',
                    input.eContainer,
                    BitcoinTMPackage.Literals.TRANSACTION_BODY__INPUTS, 
                    i
                );
                return false
            } catch(CompileException e) {
                
            }
        }
        return true
    }
    
    @Check
    def void checkPositiveOutValue(Output output) {
    	
    	var value = output.value.exp.interpret.getFirst as Integer
    	var script = output.script
    	
    	if (script.isOpReturn && value>0) {
    		error("OP_RETURN output scripts must have 0 value.",
                output,
                BitcoinTMPackage.Literals.OUTPUT__VALUE
            );
    	}
    	
    	// https://github.com/bitcoin/bitcoin/commit/6a4c196dd64da2fd33dc7ae77a8cdd3e4cf0eff1
    	if (!script.isOpReturn && value<546) {
    		error("Output (except OP_RETURN scripts) must spend at least 546 satoshis.",
                output,
                BitcoinTMPackage.Literals.OUTPUT__VALUE
            );
    	}
    }
    
    /*
     * https://en.bitcoin.it/wiki/Script
     * "Currently it is usually considered non-standard (though valid) for a transaction to have more than one OP_RETURN output or an OP_RETURN output with more than one pushdata op. "
     */
    @Check
    def void checkJustOneOpReturn(UserTransactionDeclaration tx) {
    	var tbody = tx.body
    	
    	var boolean[] error = newBooleanArrayOfSize(tbody.outputs.size);
    	    	
		for (var i=0; i<tbody.outputs.size-1; i++) {
			for (var j=i+1; j<tbody.outputs.size; j++) {
				
				var outputA = tbody.outputs.get(i)
				var outputB = tbody.outputs.get(j)
				
				// these checks need to be executed in this order
				if (outputA.script.isOpReturn && outputB.script.isOpReturn
		        ) {
					if (!error.get(i) && (error.set(i,true) && true))
			            error(
			                "You cannot define more than one OP_RETURN script per transaction.",
			                outputA.eContainer,
			                outputA.eContainingFeature,
			                i
			            );
		        
		            if (!error.get(j) && (error.set(j,true) && true))
				        error(
			                "You cannot define more than one OP_RETURN script per transaction.",
			                outputB.eContainer,
			                outputB.eContainingFeature,
			                j
			            );
		        }
			}
		}
    }
    
    @Check
    def void checkAbsoluteTime(AbsoluteTime tlock) {
    	
    	if (tlock.value<0) {
			error(
                "Negative timelock is not permitted.",
                tlock,
                BitcoinTMPackage.Literals.TIME__VALUE
            );
    	}
    	
    	if (tlock.isBlock && tlock.value>=Transaction.LOCKTIME_THRESHOLD) {
			error(
                "Block number must be lower than 500_000_000.",
                tlock,
                BitcoinTMPackage.Literals.TIME__VALUE
            );
    	}
    	
    	if (!tlock.isBlock && tlock.value<Transaction.LOCKTIME_THRESHOLD) {
    		error(
                "Block number must be greater or equal than 500_000_000 (1985-11-05 00:53:20). Found "+tlock.value,
                tlock,
                BitcoinTMPackage.Literals.TIME__VALUE
            );
    	}
    }
    
    @Check
    def void checkRelativeTime(RelativeTime tlock) {
    	
    	
    }
    
    @Check
    def void checkAfter(AfterTimeLock after) {
    	
    	// transaction containing after
    	val tx = EcoreUtil2.getContainerOfType(after, TransactionDeclaration);
    	
    	// all the txs pointing to tx
    	var txReferences = EcoreUtil2.getAllContentsOfType(EcoreUtil2.getRootContainer(after), TransactionReference).filter[v|v.tx==tx]
    	
    	// all these txs have to define the timelock
    	for (ref : txReferences) {
    		
    		val body = EcoreUtil2.getContainerOfType(ref, TransactionBody);
    		
    		// the transaction does not define a timelock
    		if (body.tlock===null) {
    			error(
	                '''Referred output requires to define a timelock.''',
	                ref.eContainer,			// INPUT
	                ref.eContainingFeature	// INPUT__TX_REF
	            );
    		}
			// transaction lock is defined
    		else {	
	    	
				// after expression uses an absolute time     	
	    		if (after.timelock.isAbsolute)  {
	    			
	        		var absTimes = body.tlock.times.filter(AbsoluteTime).map(x|x as AbsoluteTime) 

			        if(absTimes.size==0){
	 					error(
			                '''Transaction does not define an absolute timelock''',
			                body,
			                BitcoinTMPackage.Literals.TRANSACTION_BODY__TLOCK
			            );
			        }
			        else if(absTimes.size==1) {
			        	// check if they are of the same type (block|date)
			        	if (after.timelock.isBlock && !absTimes.get(0).isBlock
							|| after.timelock.isRelative && !absTimes.get(0).isRelative
						)
							error(
				                '''Transaction timelock must be of type «IF after.timelock.isBlock»block«ELSE»timestamp«ENDIF».''',
				                absTimes.get(0).eContainer,
				                absTimes.get(0).eContainingFeature
				            );
			        }
			        else {
			        	for (t : absTimes)
							error(
				                '''Only one absolute timelock is allowed''',
				                t.eContainer,
				                t.eContainingFeature
				            );
			        }
	    		}
	    		
	    		// after expression uses a relative time
	    		if (after.timelock.isRelative) {
	    			
		    		var timesPerTx = body.tlock.times
			    		.filter(RelativeTime)
			    		.filter(x | (x as RelativeTime).tx == tx)
			    		
			    	
			    	if (timesPerTx.size==0) {
			    		error(
			                '''Transaction does not define a relative timelock for transaction «ref.tx.name»''',
			                body,
			                BitcoinTMPackage.Literals.TRANSACTION_BODY__TLOCK
			            );
			    	}
			    	else if (timesPerTx.size==1) {
			    		// check if they are of the same type (block|date)
						if (after.timelock.isBlock && !timesPerTx.get(0).isBlock
							|| after.timelock.isRelative && !timesPerTx.get(0).isRelative
						)
							error(
				                '''Transaction timelock must be of type «IF after.timelock.isBlock»block«ELSE»timestamp«ENDIF».''',
				                timesPerTx.get(0).eContainer,
				                timesPerTx.get(0).eContainingFeature
				            );
			    	}
			    	else {
			    		for (t : timesPerTx)
				    		error(
				                '''Only one relative timelock is allowed per transaction''',
				                t.eContainer,
				                t.eContainingFeature
				            );
			    	}
	    		}
	    		
			} 
    	}
    	
    	
    }
    
}