/*
 * Copyright 2019 Nicola Atzei
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
 * generated by Xtext 2.11.0
 */
package xyz.balzaclang

import com.google.inject.Binder
import com.google.inject.name.Names
import xyz.balzaclang.xsemantics.validation.BalzacTypeSystemValidator
import java.io.File
import java.io.FileInputStream
import java.io.IOException
import java.util.Properties
import org.eclipse.xsemantics.runtime.StringRepresentation
import org.eclipse.xtext.conversion.IValueConverterService
import org.eclipse.xtext.scoping.IGlobalScopeProvider
import org.eclipse.xtext.scoping.IScopeProvider
import org.eclipse.xtext.scoping.impl.AbstractDeclarativeScopeProvider
import org.eclipse.xtext.scoping.impl.ImportUriResolver
import org.eclipse.xtext.scoping.impl.SimpleLocalScopeProvider
import org.eclipse.xtext.service.SingletonBinding
import xyz.balzaclang.xsemantics.BalzacStringRepresentation
import xyz.balzaclang.scoping.BalzacGlobalScopeProvider
import xyz.balzaclang.conversion.BalzacConverterService

/**
 * Use this class to register components to be used at runtime / without the Equinox extension registry.
 */
class BalzacRuntimeModule extends AbstractBalzacRuntimeModule {

    override void configure(Binder binder) {
        val trustedNodeConf = System.properties.getProperty("trustedNodesConfFile")
        if (trustedNodeConf !== null)
            tryBindPropertiesFromAbsoluteFile(binder, trustedNodeConf);
        super.configure(binder);
    }

    def Class<? extends StringRepresentation> bindStringRepresentation() {
        return BalzacStringRepresentation;
    }

    @SingletonBinding(eager=true)
    def Class<? extends BalzacTypeSystemValidator> bindBalzacTypeSystemValidator() {
        return BalzacTypeSystemValidator;
    }

    // Configure the feature name containing the imported namespace.
    // 'importedNamespace' is the name that allows to resolve cross-file references and cannot be changed
    def void configureImportUriResolver(Binder binder) {
        binder.bind(String).annotatedWith(Names.named(ImportUriResolver.IMPORT_URI_FEATURE)).toInstance("importedNamespace");
    }

    override Class<? extends IValueConverterService> bindIValueConverterService() {
        return BalzacConverterService
    }

    // fully qualified names depends on the package declaration
//    override Class<? extends IQualifiedNameProvider> bindIQualifiedNameProvider() {
//      return BalzacQualifiedNameProvider;
//  }

    // disable ImportedNamespaceAwareLocalScopeProvider
    override configureIScopeProviderDelegate(Binder binder) {
        binder.bind(IScopeProvider).annotatedWith(Names.named(AbstractDeclarativeScopeProvider.NAMED_DELEGATE)).to(SimpleLocalScopeProvider);
    }

    override Class<? extends IGlobalScopeProvider> bindIGlobalScopeProvider() {
        return BalzacGlobalScopeProvider;
    }

    def void tryBindPropertiesFromAbsoluteFile(Binder binder, String propertyFilePath) {
        try {
            val in = new FileInputStream(new File(propertyFilePath));
            if (in !== null) {
                val properties = new Properties();
                properties.load(in);
                Names.bindProperties(binder, properties);
            }
        } catch (IOException e) {
            e.printStackTrace
        }
    }
}
