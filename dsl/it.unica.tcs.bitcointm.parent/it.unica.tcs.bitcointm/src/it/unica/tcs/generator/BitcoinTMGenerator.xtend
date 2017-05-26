/*
 * generated by Xtext 2.11.0
 */
package it.unica.tcs.generator

import com.google.inject.Inject
import it.unica.tcs.bitcoinTM.AfterTimeLock
import it.unica.tcs.bitcoinTM.AndExpression
import it.unica.tcs.bitcoinTM.ArithmeticSigned
import it.unica.tcs.bitcoinTM.Between
import it.unica.tcs.bitcoinTM.BooleanLiteral
import it.unica.tcs.bitcoinTM.BooleanNegation
import it.unica.tcs.bitcoinTM.Comparison
import it.unica.tcs.bitcoinTM.DummyTxBody
import it.unica.tcs.bitcoinTM.Equals
import it.unica.tcs.bitcoinTM.Expression
import it.unica.tcs.bitcoinTM.Hash
import it.unica.tcs.bitcoinTM.IfThenElse
import it.unica.tcs.bitcoinTM.Input
import it.unica.tcs.bitcoinTM.KeyDeclaration
import it.unica.tcs.bitcoinTM.Max
import it.unica.tcs.bitcoinTM.Min
import it.unica.tcs.bitcoinTM.Minus
import it.unica.tcs.bitcoinTM.Model
import it.unica.tcs.bitcoinTM.NumberLiteral
import it.unica.tcs.bitcoinTM.OrExpression
import it.unica.tcs.bitcoinTM.Output
import it.unica.tcs.bitcoinTM.Parameter
import it.unica.tcs.bitcoinTM.Plus
import it.unica.tcs.bitcoinTM.SerialTxBody
import it.unica.tcs.bitcoinTM.Signature
import it.unica.tcs.bitcoinTM.SignatureType
import it.unica.tcs.bitcoinTM.Size
import it.unica.tcs.bitcoinTM.StringLiteral
import it.unica.tcs.bitcoinTM.TransactionDeclaration
import it.unica.tcs.bitcoinTM.UserDefinedTxBody
import it.unica.tcs.bitcoinTM.VariableReference
import it.unica.tcs.bitcoinTM.Versig
import it.unica.tcs.xsemantics.BitcoinTMTypeSystem
import java.io.File
import java.util.HashMap
import org.bitcoinj.core.Coin
import org.bitcoinj.core.DumpedPrivateKey
import org.bitcoinj.core.ECKey
import org.bitcoinj.core.Transaction
import org.bitcoinj.core.TransactionInput
import org.bitcoinj.core.TransactionOutPoint
import org.bitcoinj.core.TransactionOutput
import org.bitcoinj.core.Utils
import org.bitcoinj.script.Script
import org.bitcoinj.script.Script.ScriptType
import org.bitcoinj.script.ScriptBuilder
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.AbstractGenerator
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext

import static org.bitcoinj.script.ScriptOpCodes.*

import static extension it.unica.tcs.validation.BitcoinJUtils.*
import org.bitcoinj.core.Transaction.SigHash

/**
 * Generates code from your model files on save.
 * 
 * See https://www.eclipse.org/Xtext/documentation/303_runtime_concepts.html#code-generation
 */
class BitcoinTMGenerator extends AbstractGenerator {

    public val COMPILER_VERSION = 0xCAFEBABE;

    public static class CompilationException extends RuntimeException {
        
        new() {
            this("compile error")
        }
        
        new(String message) {
            super(message)
        }
    }

    @Inject private BitcoinTMTypeSystem typeSystem

    override void doGenerate(Resource resource, IFileSystemAccess2 fsa, IGeneratorContext context) {

        var resourceName = resource.URI.lastSegment.replace(".btm", "")

        for (e : resource.allContents.toIterable.filter(Model)) {

//			var basepath = if (e.^package==null) "" else e.^package.fullyQualifiedName.toString(File.separator) ;
            var outputFilename = "" + File.separator + resourceName + ".test"

            println('''generating «outputFilename»''')
            fsa.generateFile(outputFilename, e.compile)
        }
    }

    def dispatch String compile(EObject obj) {
        throw new CompilationException
    }

    def dispatch String compile(Model obj) {
        obj.declarations.map[x|x.compile].join("\n")
    }

    def dispatch String compile(KeyDeclaration obj) {
        ""
    }

    def dispatch String compile(TransactionDeclaration obj) {
        '''transaction «obj.name» «obj.body.compile»'''
    }

    def dispatch String compile(DummyTxBody obj) {"<dummy>"}
    def dispatch String compile(SerialTxBody obj) {"<serial>"}
    
    
    def dispatch String compile(UserDefinedTxBody obj) {
        '''{
			input  [
				«FOR i : obj.inputs»
				«i.compile»
				«ENDFOR»
			]
			output [
				«FOR i : obj.outputs»
				«i.compile»
				«ENDFOR»
			]
		}'''
    }

    def dispatch String compile(Input obj) {
        obj.compileInput?.toString
    }

    def dispatch String compile(Output obj) {
        obj.compileOutput?.toString
    }

    var altstackSize = 0
    val altstackPositions = new HashMap<Parameter, Integer>()

    /*
     * utility methods
     */
    def boolean isP2PKH(it.unica.tcs.bitcoinTM.Script script) {
        var onlyOneSignatureParam = script.params.size == 1 && (script.params.get(0).paramType instanceof SignatureType)
        var onlyOnePubkey = (script.exp instanceof Versig) && (script.exp as Versig).pubkeys.size == 1

        return onlyOneSignatureParam && onlyOnePubkey
    }

    def boolean isOpReturn(it.unica.tcs.bitcoinTM.Script script) {
        var noParam = script.params.size == 0
        var onlyString = script.exp instanceof StringLiteral

        return noParam && onlyString
    }

    def boolean isP2SH(it.unica.tcs.bitcoinTM.Script script) {
        return !script.isP2PKH && !script.isOpReturn
    }


    

    /*
     * 
     * compiler: AST --> BitcoinJ
     * 
     */
     
    /**
     * Create a bitcoinj transaction object recursively.
     * Each transaction is bound to another one by its inputs. Recursion
     * stops when either a coinbase transaction or a serialized transaction is reached.
     */
    def dispatch Transaction toTransaction(UserDefinedTxBody stmt) {
        
        var netParams = stmt.networkParams        
        var Transaction tx = new Transaction(netParams)
        
        for (input : stmt.inputs) {
            var outIndex = input.txRef.idx
            var txToRedeem = input.txRef.tx.body.toTransaction
            var outPoint = new TransactionOutPoint(netParams, outIndex, txToRedeem)
            var TransactionInput txInput = new TransactionInput(netParams, tx, input.compileInput.program, outPoint)
            tx.addInput(txInput)            
        }
        
        for (output : stmt.outputs) {
            var value = if (output.value.unit=="BTC") Coin.COIN.times(output.value.value) else Coin.SATOSHI.times(output.value.value)
            var txOutput = new TransactionOutput(netParams, tx, value, output.compileOutput.program)
            tx.addOutput(txOutput)
        }
        
        return tx    
    }
    
    /**
     * Deserialiaze the transaction bytes into a bitcoinj transaction.
     * We assume the byte string to be valid.
     */ 
    def dispatch Transaction toTransaction(SerialTxBody stmt) {
        return new Transaction(stmt.networkParams, Utils.HEX.decode(stmt.bytes))
    }
    
    /**
     * Create a bitcoinj coinbase transaction.
     * The amount of money that can be spend is taken from the network parameters.
     * 
     * @return a coinbase tx with a lot of money always redeemable
     */
    def dispatch Transaction toTransaction(DummyTxBody stmt) {
        var netParams = stmt.networkParams
        var tx = new Transaction(netParams);
        var txInput = new TransactionInput(netParams, tx, new ScriptBuilder().number(42).build().getProgram());
        var txOutput = new TransactionOutput(netParams, tx, netParams.maxMoney, new ScriptBuilder().number(1).build().getProgram());      
        
        tx.addInput(txInput);
        tx.addOutput(txOutput);
        
        return tx
    }
    


    /**
     * Prepend version
     */
    def ScriptBuilder prependVersion(ScriptBuilder sb) {
        sb.op(0, OP_DROP).number(COMPILER_VERSION)
        return sb
    }

    def Script compileInput(Input stmt) {
        var outIdx = stmt.txRef.idx

        if (stmt.txRef.tx.body instanceof UserDefinedTxBody){
            
            var inputTx = stmt.txRef.tx.body as UserDefinedTxBody       
            var output = inputTx.outputs.get(outIdx);
    
            if (output.script.isP2PKH) {
                var sig = stmt.actual.exps.get(0) as Signature
                var pubkey = sig.key.body.pvt.value.privateKeyToPubkeyBytes(stmt.networkParams)
                
                val sb = new ScriptBuilder()
    
                sig.compileExpression(sb)
                sb.data(pubkey)
    
                /* <sig> <pubkey> */
                sb.build
            } else if (output.script.isP2SH) {
                
                // reset
                altstackSize = 0 
                altstackPositions.clear
                   
                val expSb = new ScriptBuilder()
                val scriptSb = new ScriptBuilder()
                
                // build the list of expression pushes (actual parameters) 
                stmt.actual.exps.forEach[e|e.compileExpression(expSb)]
                
                // build the redeem script to serialize
                for (var i = 0; i < output.script.params.size; i++) {
                    var Parameter p = output.script.params.get(i)
                    altstackPositions.put(p, altstackSize++)
                    scriptSb.op(0, OP_TOALTSTACK)
                }
                output.script.exp.compileExpression(scriptSb)
                
                expSb.data(scriptSb.build.program)
                                
                println("-- P2SH --")
                println(expSb.build)
                println(Utils.HEX.encode(Utils.sha256hash160(scriptSb.build.program)))
                
                /* <e1> ... <en> <serialized script> */
                expSb.build
            } else
                throw new UnsupportedOperationException
        }
        else if (stmt.txRef.tx.body instanceof SerialTxBody){
            var output = stmt.txRef.tx.body.toTransaction.getOutput(outIdx)
            
            if (output.scriptPubKey.isSentToAddress) {
                var sig = stmt.actual.exps.get(0) as Signature
                var pubkey = sig.key.body.pvt.value.privateKeyToPubkeyBytes(stmt.networkParams)
                
                val sb = new ScriptBuilder()
    
                sig.compileExpression(sb)
                sb.data(pubkey)
    
                /* <sig> <pubkey> */
                sb.build
            } else if (output.scriptPubKey.isPayToScriptHash) {
                
                val sb = new ScriptBuilder(output.scriptPubKey)
                
                stmt.actual.exps.forEach[e|e.compileExpression(sb)]
                sb.data(sb.build.program)   // sbagliato!!!
    
                /* <e1> ... <en> <serialized script> */
                
                val sb1 = new ScriptBuilder()
                
                if (stmt.actual.script===null)
                    throw new CompilationException
                
                stmt.actual.script.exp.compileExpression(sb1)

                if (
                    output.scriptPubKey.chunks.get(0).data == COMPILER_VERSION
                ) {
                    // if the script was compiled using the tool
                    // prepend OP_TOALTSTACK
                    for (var i=0; i<stmt.actual.exps.size; i++)
                        sb.op(0, OP_TOALTSTACK)
                }
                
                sb.build
            } else
                throw new UnsupportedOperationException
        }
        else if (stmt.txRef.tx.body instanceof DummyTxBody){
            new ScriptBuilder().number(1).build
        }
    }

    def Script compileOutput(Output output) {

        var outScript = output.script

        if (outScript.isP2PKH) {
            var versig = outScript.exp as Versig
            var pk = versig.pubkeys.get(0).body.pub.value.wifToAddress(output.networkParams)

            var script = ScriptBuilder.createOutputScript(pk)

            if (script.scriptType != ScriptType.P2PKH)
                throw new CompilationException

            /* OP_DUP OP_HASH160 <pkHash> OP_EQUALVERIFY OP_CHECKSIG */
            script
        } else if (outScript.isP2SH) {
            
            val scriptSb = new ScriptBuilder()
            
            // build the redeem script to serialize
            for (var i = 0; i < outScript.params.size; i++) {
                var Parameter p = outScript.params.get(i)
                altstackPositions.put(p, altstackSize++)
                scriptSb.op(0, OP_TOALTSTACK)
            }
            outScript.exp.compileExpression(scriptSb)
            
            var script = ScriptBuilder.createP2SHOutputScript(scriptSb.build)

            if (script.scriptType != ScriptType.P2SH)
                throw new CompilationException

            /* OP_HASH160 <script hash-160> OP_EQUAL */
            script
        } else if (outScript.isOpReturn) {
            var c = outScript.exp as StringLiteral
            var script = ScriptBuilder.createOpReturnScript(c.value.bytes)

            if (script.scriptType != ScriptType.NO_TYPE)
                throw new CompilationException

            /* OP_RETURN <bytes> */
            script
        } else
            throw new UnsupportedOperationException
    }



    /*
     * EXPRESSIONS
     * 
     * N.B. the compiler tries to simplify simple expressions like
     * <ul> 
     *  <li> 1+2 ≡ 3
     *  <li> if (12==10+2) then "foo" else "bar" ≡ "foo"
     * </ul>
     */
    def dispatch void compileExpression(Expression exp, ScriptBuilder sb) {
        throw new UnsupportedOperationException
    }
    
    def dispatch void compileExpression(KeyDeclaration stmt, ScriptBuilder sb) {
        /* push the public key */
        val pvtkey = stmt.body.pvt.value
        val key = DumpedPrivateKey.fromBase58(stmt.networkParams, pvtkey).key

        sb.data(key.pubKey)
    }

    def dispatch void compileExpression(Hash hash, ScriptBuilder sb) {
        hash.value.compileExpression(sb)
        sb.op(OP_HASH160)
    }

    def dispatch void compileExpression(AfterTimeLock stmt, ScriptBuilder sb) {
        stmt.time.compileExpression(sb)
        sb.op(OP_CHECKLOCKTIMEVERIFY)
        stmt.continuation.compileExpression(sb)
    }

    def dispatch void compileExpression(AndExpression stmt, ScriptBuilder sb) {
        var res = typeSystem.interpret(stmt)
        
        if (res.failed) {
            
        }
        stmt.left.compileExpression(sb)
        stmt.right.compileExpression(sb)
        sb.op(OP_BOOLAND)
    }

    def dispatch void compileExpression(OrExpression stmt, ScriptBuilder sb) {
        var res = typeSystem.interpret(stmt)
        
        if (res.failed) {
            
        }        
        stmt.left.compileExpression(sb)
        stmt.right.compileExpression(sb)
        sb.op(OP_BOOLOR)
    }

    def dispatch void compileExpression(Plus stmt, ScriptBuilder sb) {
        var res = typeSystem.interpret(stmt)
        
        if (res.failed) {
            stmt.left.compileExpression(sb)
            stmt.right.compileExpression(sb)
            sb.op(OP_ADD)
        }
        else {
            if (res.first instanceof String){
                sb.data((res.first as String).bytes)
            }
            else if (res.first instanceof Integer) {
                sb.number(res.first as Integer)
            }
            else throw new CompilationException            
        }
    }

    def dispatch void compileExpression(Minus stmt, ScriptBuilder sb) {
        var res = typeSystem.interpret(stmt)
        
        if (res.failed) {
            stmt.left.compileExpression(sb)
            stmt.right.compileExpression(sb)
            sb.op(OP_SUB)
        }
        else {
            if (res.first instanceof Integer) {
                sb.number(res.first as Integer)
            }
            else throw new CompilationException 
        }
    }

    def dispatch void compileExpression(Max stmt, ScriptBuilder sb) {
        var res = typeSystem.interpret(stmt)
        
        if (res.failed) {
            stmt.left.compileExpression(sb)
            stmt.right.compileExpression(sb)
            sb.op(OP_MAX)
        }
        else {
            if (res.first instanceof Integer) {
                sb.number(res.first as Integer)
            }
            else throw new CompilationException 
        }
    }

    def dispatch void compileExpression(Min stmt, ScriptBuilder sb) {
        var res = typeSystem.interpret(stmt)
        
        if (res.failed) {
            stmt.left.compileExpression(sb)
            stmt.right.compileExpression(sb)
            sb.op(OP_MIN)
        }
        else {
            if (res.first instanceof Integer) {
                sb.number(res.first as Integer)
            }
            else throw new CompilationException 
        }
    }

    def dispatch void compileExpression(Size stmt, ScriptBuilder sb) {
        stmt.value.compileExpression(sb)
        sb.op(OP_SIZE)
    }

    def dispatch void compileExpression(BooleanNegation stmt, ScriptBuilder sb) {
        var res = typeSystem.interpret(stmt)
        
        if (res.failed) {
            stmt.exp.compileExpression(sb)
            sb.op(OP_NOT)            
        }
        else {
            if (res.first instanceof Boolean) {
                if (res.first as Boolean) {
                    sb.number(OP_TRUE)
                }
                else sb.number(OP_FALSE)
            }
            else throw new CompilationException 
        }
    }

    def dispatch void compileExpression(ArithmeticSigned stmt, ScriptBuilder sb) {
        var res = typeSystem.interpret(stmt)
        
        if (res.failed) {
            stmt.exp.compileExpression(sb)
            sb.op(OP_NEGATE)
        }
        else {
            if (res.first instanceof Integer) {
                sb.number(res.first as Integer)
            }
            else throw new CompilationException 
        }
    }

    def dispatch void compileExpression(Between stmt, ScriptBuilder sb) {
        var res = typeSystem.interpret(stmt)
        
        if (res.failed) {
            stmt.value.compileExpression(sb)
            stmt.left.compileExpression(sb)
            stmt.right.compileExpression(sb)
            sb.op(OP_WITHIN)
        }
        else {
            if (res.first instanceof Integer) {
                sb.number(res.first as Integer)
            }
            else throw new CompilationException 
        }
    }

    def dispatch void compileExpression(Comparison stmt, ScriptBuilder sb) {
        var res = typeSystem.interpret(stmt)
        
        if (res.failed) {
            stmt.left.compileExpression(sb)
            stmt.right.compileExpression(sb)
    
            switch (stmt.op) {
                case "<": sb.op(OP_LESSTHAN)
                case ">": sb.op(OP_GREATERTHAN)
                case "<=": sb.op(OP_LESSTHANOREQUAL)
                case ">=": sb.op(OP_GREATERTHANOREQUAL)
            }
        }
        else {
            if (res.first instanceof Boolean) {
                if (res.first as Boolean) {
                    sb.number(OP_TRUE)
                }
                else sb.number(OP_FALSE)
            }
            else throw new CompilationException 
        }
    }
    
    def dispatch void compileExpression(Equals stmt, ScriptBuilder sb) {
        var res = typeSystem.interpret(stmt)
        
        if (res.failed) {
            stmt.left.compileExpression(sb)
            stmt.right.compileExpression(sb)
            sb.op(OP_EQUAL)
        }
        else {
            if (res.first instanceof Boolean) {
                if (res.first as Boolean) {
                    sb.number(OP_TRUE)
                }
                else sb.number(OP_FALSE)
            }
            else throw new CompilationException 
        }
    }

    def dispatch void compileExpression(IfThenElse stmt, ScriptBuilder sb) {
        var res = typeSystem.interpret(stmt)
        
        if (res.failed) {
            stmt.^if.compileExpression(sb)
            sb.op(OP_IF)
            stmt.then.compileExpression(sb)
            sb.op(OP_ELSE)
            stmt.^else.compileExpression(sb)
            sb.op(OP_ENDIF)            
        }
        else {
            if (res.first instanceof String){
                sb.data((res.first as String).bytes)
            }
            else if (res.first instanceof Integer) {
                sb.number(res.first as Integer)
            }
            else if (res.first instanceof Boolean) {
                if (res.first as Boolean) {
                    sb.number(OP_TRUE)
                }
                else sb.number(OP_FALSE)
            }
            else throw new CompilationException            
        }
    }

    def dispatch void compileExpression(Versig stmt, ScriptBuilder sb) {
        if (stmt.pubkeys.size == 1) {
            stmt.signatures.get(0).compileExpression(sb)
            stmt.pubkeys.get(0).compileExpression(sb)
            sb.op(OP_CHECKSIG)
        } else {
            sb.number(OP_0)
            stmt.signatures.forEach[s|s.compileExpression(sb)]
            sb.number(stmt.signatures.size)
            stmt.pubkeys.forEach[k|k.compileExpression(sb)]
            sb.number(stmt.pubkeys.size)
            sb.op(OP_CHECKMULTISIG)
        }
    }

    def dispatch void compileExpression(NumberLiteral n, ScriptBuilder sb) {
        sb.number(n.value).build().toString
    }

    def dispatch void compileExpression(BooleanLiteral n, ScriptBuilder sb) {
        sb.number(if(n.isTrue) OP_TRUE else OP_FALSE).build().toString
    }

    def dispatch void compileExpression(StringLiteral s, ScriptBuilder sb) {
        sb.data(s.value.bytes).build().toString
    }

    def dispatch void compileExpression(Signature stmt, ScriptBuilder sb) {
        
        var tx = stmt.containingTransaction
		var pvtKey = stmt.key.body.pvt.value
		
        var inputIndex = stmt.containingInputIndex
		var key = ECKey.fromPrivate(Utils.parseAsHexOrBase58(pvtKey));
            
        var sigHash = switch(stmt.modifier) {
            case AIAO,
            case SIAO: SigHash.ALL
            case AISO,
            case SISO: SigHash.SINGLE
            case AINO,
            case SINO: SigHash.NONE
        }
        
        var anyoneCanPay = switch(stmt.modifier) {
            case SIAO,
            case SISO,
            case SINO: true
            case AIAO,
            case AISO,
            case AINO: false
        }
            
        /*
         * store the information to compute the signature later
         */
        
        sb.data(('''<sig «stmt.key.name» «stmt.modifier»>''' + "").bytes)
    }

    def dispatch void compileExpression(VariableReference varRef, ScriptBuilder sb) {
        /*
         * N: altezza dell'altstack
         * i: posizione della variabile interessata
         * 
         * OP_FROMALTSTACK( N - i )                svuota l'altstack fino a raggiungere x
         * 	                                       x ora è in cima al main stack
         * 
         * OP_DUP OP_TOALTSTACK        	           duplica x e lo rimanda sull'altstack
         * 
         * (OP_SWAP OP_TOALTSTACK)( N - i - 1 )    prende l'elemento sotto x e lo sposta sull'altstack
         * 
         */
        var param = varRef.ref
        var pos = altstackPositions.get(param)

        if(pos === null) throw new CompilationException;

        (1 .. altstackSize - pos).forEach[x|sb.op(OP_FROMALTSTACK)]
        sb.op(OP_DUP).op(OP_TOALTSTACK)

        if (altstackSize - pos - 1 > 0)
            (1 .. altstackSize - pos - 1).forEach[x|sb.op(OP_SWAP).op(OP_TOALTSTACK)]
    }
    
    
    def dispatch Transaction getContainingTransaction(EObject obj) {
        return obj.eContainer.containingTransaction
    }
    
    def dispatch Transaction getContainingTransaction(TransactionDeclaration tx) {
        return tx.body.toTransaction
    }
    
    def dispatch int getContainingInputIndex(EObject obj) {
        return obj.eContainer.getContainingInputIndex
    }
    
    def dispatch int getContainingInputIndex(Input input) {
        var tx = input.eContainer as UserDefinedTxBody
        for (var i=0; i<tx.inputs.size; i++) {
            if (tx.inputs.get(i)==input) {
                return i
            }
        }
        throw new CompilationException
    }
}
