package it.unica.tcs.lib;

import static com.google.common.base.Preconditions.checkArgument;
import static com.google.common.base.Preconditions.checkNotNull;
import static com.google.common.base.Preconditions.checkState;

import java.util.HashMap;
import java.util.Map;
import java.util.Set;

import com.google.common.collect.ImmutableSet;
import com.google.common.collect.Sets;

import it.unica.tcs.lib.utils.TablePrinter;

public class Env<T> implements EnvI<T,Env<T>> {
	
	private static final long serialVersionUID = 1L;
	private final Map<String,Class<? extends T>> variablesType = new HashMap<>();
	private final Map<String,T> variablesBinding = new HashMap<>();
		
	@Override
	public boolean hasVariable(String name) {
		return variablesType.containsKey(name);
	}

	@Override
	public boolean isFree(String name) {
		checkNotNull(name, "'name' cannot be null");
		checkArgument(hasVariable(name), "'%s' is not a variable", name);
		return !isBound(name);
	}

	@Override
	public boolean isBound(String name) {
		checkNotNull(name, "'name' cannot be null");
		checkArgument(hasVariable(name), "'%s' is not a variable", name);
		return variablesBinding.containsKey(name);
	}

	@Override
	public Class<? extends T> getType(String name) {
		checkNotNull(name, "'name' cannot be null");
		checkArgument(hasVariable(name), "'%s' is not a variable", name);
		return variablesType.get(name);
	}
	
	@Override
	public T getValue(String name) {
		checkNotNull(name, "'name' cannot be null");
		checkArgument(hasVariable(name), "'%s' is not a variable", name);
		checkArgument(isBound(name), "'%s' is not bound", name);
		return variablesBinding.get(name);
	}
	
	@Override
	public T getValueOrDefault(String name, T defaultValue) {
		checkNotNull(name, "'name' cannot be null");
		checkNotNull(defaultValue, "'defaultValue' cannot be null");
		checkArgument(hasVariable(name), "'%s' is not a variable", name);
		return isBound(name)? getValue(name): defaultValue;
	}
	
	@Override
	public <A extends T> A getValue(String name, Class<A> type) {
		checkNotNull(name, "'name' cannot be null");
		checkNotNull(type, "'type' cannot be null");
		Class<? extends T> expectedType = getType(name);
		checkState(expectedType.equals(type));
		return type.cast(variablesBinding.get(name));
	}

	@Override
	public Env<T> addVariable(String name, Class<? extends T> type) {
		checkNotNull(name, "'name' cannot be null");
		checkNotNull(type, "'type' cannot be null");
		checkArgument(!hasVariable(name) || type.equals(getType(name)), "'"+name+"' is already associated with class '"+variablesType.get(name)+"'");
		variablesType.put(name, type);
		return this;
	}
	
	@Override
	public Env<T> removeVariable(String name) {
		checkNotNull(name, "'name' cannot be null");
		checkArgument(hasVariable(name), "'%s' is not a variable", name);
		variablesType.remove(name);
		variablesBinding.remove(name);
		return this;
	}

	@Override
	public Env<T> bindVariable(String name, T value) {
		checkNotNull(name, "'name' cannot be null");
		checkNotNull(value, "'value' cannot be null");
		checkArgument(hasVariable(name), "'%s' is not a variable", name);
		checkArgument(getType(name).isInstance(value), "'"+name+"' is associated with class '"+getType(name)+"', but 'value' is object of class '"+value.getClass()+"'");
		checkArgument(isFree(name), "'"+name+"' is already associated with value '"+variablesBinding.get(name)+"'");
		variablesBinding.put(name, value);
		return this;
	}

	@Override
	public Set<String> getVariables() {
		return ImmutableSet.copyOf(variablesType.keySet());
	}

	@Override
	public Set<String> getFreeVariables() {
		return Sets.difference(getVariables(), getBoundVariables());
	}

	@Override
	public Set<String> getBoundVariables() {
		return ImmutableSet.copyOf(variablesBinding.keySet());
	}

	@Override
	public boolean isReady() {
		return getFreeVariables().size()==0;
	}

	@Override
	public void clear() {
		variablesType.clear();
		variablesBinding.clear();
	}
	
	@Override
	public String toString() {
		TablePrinter tp = new TablePrinter(new String[]{"Name","Type","Binding"}, "No variables");
		Set<String> variables = getVariables();
		for (String name : variables) {
			tp.addRow(name, getType(name).getSimpleName(), isBound(name)? getValue(name).toString(): "");
		}
		return tp.toString();
	}

	@Override
	public int hashCode() {
		final int prime = 31;
		int result = 1;
		result = prime * result + ((variablesBinding == null) ? 0 : variablesBinding.hashCode());
		result = prime * result + ((variablesType == null) ? 0 : variablesType.hashCode());
		return result;
	}

	@Override
	public boolean equals(Object obj) {
		if (this == obj)
			return true;
		if (obj == null)
			return false;
		if (getClass() != obj.getClass())
			return false;
		Env<?> other = (Env<?>) obj;
		if (variablesBinding == null) {
			if (other.variablesBinding != null)
				return false;
		} else if (!variablesBinding.equals(other.variablesBinding))
			return false;
		if (variablesType == null) {
			if (other.variablesType != null)
				return false;
		} else if (!variablesType.equals(other.variablesType))
			return false;
		return true;
	}

}
