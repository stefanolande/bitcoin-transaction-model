/*
 * Copyright 2017 Nicola Atzei
 */

/*
 * generated by Xtext 2.11.0
 */
package it.unica.tcs.ui.contentassist

import com.google.inject.Inject
import it.unica.tcs.bitcoinTM.BitcoinTMPackage
import it.unica.tcs.bitcoinTM.PackageDeclaration
import java.util.HashSet
import java.util.Set
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.Assignment
import org.eclipse.xtext.naming.IQualifiedNameConverter
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.resource.IContainer
import org.eclipse.xtext.resource.IEObjectDescription
import org.eclipse.xtext.resource.IResourceDescription
import org.eclipse.xtext.resource.IResourceDescriptions
import org.eclipse.xtext.resource.impl.ResourceDescriptionsProvider
import org.eclipse.xtext.ui.editor.contentassist.ContentAssistContext
import org.eclipse.xtext.ui.editor.contentassist.ICompletionProposalAcceptor

/**
 * See https://www.eclipse.org/Xtext/documentation/304_ide_concepts.html#content-assist
 * on how to customize the content assistant.
 */
class BitcoinTMProposalProvider extends AbstractBitcoinTMProposalProvider {

    @Inject private ResourceDescriptionsProvider resourceDescriptionsProvider;
    @Inject private IContainer.Manager containerManager;
    @Inject private extension IQualifiedNameConverter qualifiedNameConverter

    override void completeImport_ImportedNamespace(EObject model, Assignment assignment, ContentAssistContext context, ICompletionProposalAcceptor acceptor) {
        super.completeImport_ImportedNamespace(model, assignment, context, acceptor)

        var packageName = (model.eContainer as PackageDeclaration).name.toQualifiedName

        var Set<QualifiedName> names = new HashSet();
        var IResourceDescriptions resourceDescriptions = resourceDescriptionsProvider.getResourceDescriptions(model.eResource());
        var IResourceDescription resourceDescription = resourceDescriptions.getResourceDescription(model.eResource().getURI());

        for (IContainer c : containerManager.getVisibleContainers(resourceDescription, resourceDescriptions)) {
            for (IEObjectDescription od : c.getExportedObjectsByType(BitcoinTMPackage.Literals.PACKAGE_DECLARATION)) {
                if (!packageName.equals(od.qualifiedName))
                    names.add(od.qualifiedName.append("*"))
            }
            for (IEObjectDescription od : c.getExportedObjectsByType(BitcoinTMPackage.Literals.TRANSACTION)) {
                if (!packageName.equals(od.qualifiedName.skipLast(1)))
                    names.add(od.qualifiedName)
            }
        }

        for (n : names) {
            acceptor.accept(createCompletionProposal(n.toString, context))
        }
    }
}
