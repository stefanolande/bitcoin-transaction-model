/*
 * Copyright 2019 Nicola Atzei
 */

package it.unica.tcs.lib.validation;

import org.bitcoinj.core.Address;
import org.bitcoinj.core.AddressFormatException;
import org.bitcoinj.core.AddressFormatException.InvalidCharacter;
import org.bitcoinj.core.AddressFormatException.InvalidChecksum;
import org.bitcoinj.core.AddressFormatException.InvalidDataLength;
import org.bitcoinj.core.AddressFormatException.WrongNetwork;
import org.bitcoinj.core.DumpedPrivateKey;
import org.bitcoinj.core.Transaction;
import org.bitcoinj.core.VerificationException;
import org.bitcoinj.script.Script;
import org.bitcoinj.script.ScriptException;

import it.unica.tcs.lib.ECKeyStore;
import it.unica.tcs.lib.client.BitcoinClient;
import it.unica.tcs.lib.client.TransactionNotFoundException;
import it.unica.tcs.lib.model.ITransactionBuilder;
import it.unica.tcs.lib.model.NetworkType;
import it.unica.tcs.lib.utils.BitcoinUtils;
import it.unica.tcs.lib.validation.ValidationResult.InputValidationError;

public class Validator {

    public static ValidationResult checkWitnessesCorrecltySpendsOutputs(ITransactionBuilder txBuilder, ECKeyStore keyStore) {
        // preconditions
        if (txBuilder.isCoinbase()) {
            return ValidationResult.ok("Transaction is a coinbase");
        }
        if (!txBuilder.isReady()) {
            return ValidationResult.ok("Transaction is not ready");
        }
        
        try {
            Transaction tx = txBuilder.toTransaction(keyStore);
            for (int i=0; i<tx.getInputs().size(); i++) {
                Script inputScript = tx.getInput(i).getScriptSig();
                Script outputScript = tx.getInput(i).getOutpoint().getConnectedOutput().getScriptPubKey();

                try {
                    inputScript.correctlySpends(tx, i, outputScript, Script.ALL_VERIFY_FLAGS);
                }
                catch (ScriptException e) {
                    return new InputValidationError(i, e.getMessage(), inputScript, outputScript);
                }
            }
            return ValidationResult.ok("All inputs correctly spend their outputs");
        }
        catch(Exception e) {
            String message = "Generic error.";
            message += e.getMessage() != null? " Details: " + e.getMessage() : "";
            return ValidationResult.error(message);
        }
    }

    public static ValidationResult validateTransactionById(String txid, BitcoinClient client, NetworkType params) {
        return transactionExceptionHandler(() -> {
            String bytes = client.getRawTransaction(txid);
            Transaction tx = new Transaction(params.toNetworkParameters(), BitcoinUtils.decode(bytes));
            tx.verify();            
        });
    }

    public static ValidationResult validateRawTransaction(String bytes, NetworkType params) {
        return transactionExceptionHandler(() -> {
            Transaction tx = new Transaction(params.toNetworkParameters(), BitcoinUtils.decode(bytes));
            tx.verify();            
        });
    }

    public static ValidationResult validatePrivateKey(String wif, NetworkType params) {
        return base58ExceptionHandler(() -> {            
            DumpedPrivateKey.fromBase58(params.toNetworkParameters(), wif);
        });
    }
    
    public static ValidationResult validateAddress(String wif, NetworkType params) {
        return base58ExceptionHandler(() -> {            
            Address.fromString(params.toNetworkParameters(), wif);
        });
    }

    private static ValidationResult base58ExceptionHandler(Runnable body) {
        String message = "Unknown error";
        try {
            body.run();
            return ValidationResult.ok();
        }
        catch (InvalidChecksum e) {
            message = "Checksum does not validate";
        }
        catch (InvalidCharacter e) {
            message = "Invalid character '" + Character.toString(e.character) + "' at position " + e.position;
        }
        catch (InvalidDataLength e) {
            message = "Invalid data length";
        }
        catch (WrongNetwork e) {
            message = "Wrong network type";
        }
        catch (AddressFormatException e) {
            message = "Unable to decode";
        }
        catch (Exception e) {
            message = "Generic error.";
            message += e.getMessage() != null? " Details: " + e.getMessage() : "";
        }
        return ValidationResult.error(message);        
    }

    private static ValidationResult transactionExceptionHandler(Runnable body) {
        String message = "Unknown error";
        try {
            body.run();
            return ValidationResult.ok();
        }
        catch (TransactionNotFoundException e) {
            message = "Transaction not found. Make sure you are in the correct network";
        }
        catch (VerificationException e) {
            message = "Transaction is invalid. Details: " + e.getMessage();
        }
        catch (Exception e) {
            message = "Generic error.";
            message += e.getMessage() != null? " Details: " + e.getMessage() : "";
        }
        return ValidationResult.error(message);        
    }

}
