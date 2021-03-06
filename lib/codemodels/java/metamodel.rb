require 'rgen/metamodel_builder'
require 'java'
require 'codemodels'
require 'codemodels/javaparserwrapper'

module CodeModels
module Java

	class JavaNode < CodeModelsAstNode
	end

	JavaString  = ::Java::JavaClass.for_name("java.lang.String")
	JavaList    = ::Java::JavaClass.for_name("java.util.List")
	JavaBoolean = ::Java::boolean.java_class
	JavaInt = ::Java::int.java_class
	JapaMethodDeclaration = ::Java::JavaClass.for_name("japa.parser.ast.body.MethodDeclaration")

	MappedAstClasses = {}

	def self.wrap(ast_names)		

		# first create all the classes
		ast_names.each do |ast_name|
			java_class = ::Java::JavaClass.for_name("japa.parser.ast.#{ast_name}")
			java_super_class = java_class.superclass
			if java_super_class.name == 'japa.parser.ast.Node'
				super_class = JavaNode
			else
				raise "Super class #{java_super_class.name} of #{java_class.name}. It should be wrapped before!" unless MappedAstClasses[java_super_class]
				super_class = MappedAstClasses[java_super_class]
			end
			#puts "Java Super Class: #{java_super_class.name}"
			ast_class = java_class.ruby_class
			# TODO it should extend the right class...
			c = Class.new(super_class)
			raise "Already mapped! #{ast_name}" if MappedAstClasses[java_class]
			MappedAstClasses[java_class] = c
			Java.const_set CodeModels::JavaParserWrapper::Utils.simple_java_class_name(ast_class), c
		end

		# then add all the properties and attributes
		ast_names.each do |ast_name|
			java_class = ::Java::JavaClass.for_name("japa.parser.ast.#{ast_name}")
			ast_class = java_class.ruby_class
			c = MappedAstClasses[java_class]

			props_to_ignore = ['modifiers','arrayCount','operator','comments','javaDoc','varArgs','interface']
				
			c.class_eval do
				ast_class.java_class.declared_instance_methods.select {|m| m.name.start_with?('get')||m.name.start_with?('is') }.each do |m|
					prop_name = CodeModels::Java.property_name(m)
					unless props_to_ignore.include?(prop_name)
						if m.return_type==JavaString
							has_attr prop_name, String
						elsif m.return_type==JavaBoolean
							has_attr prop_name, RGen::MetamodelBuilder::DataTypes::Boolean
						elsif m.return_type==JavaInt
							has_attr prop_name, Integer
						elsif MappedAstClasses.has_key?(m.return_type)
							contains_one_uni prop_name, MappedAstClasses[m.return_type]
						elsif m.return_type==JavaList
		#					puts "Property #{prop_name} is a list"
							type_name = CodeModels::Java.get_generic_param(m.to_generic_string)
							last = type_name.index '>'
							type_name = type_name[0..last-1]
							type_ast_class = MappedAstClasses.keys.find{|k| k.name==type_name}
							if type_ast_class
								contains_many_uni prop_name, MappedAstClasses[type_ast_class]
							else
								raise "#{ast_name}) Property (many) #{prop_name} is else: #{type_name}"
							end
						elsif m.return_type.enum?
							has_attr prop_name, String
						else
							raise "#{ast_name}) Property (single) #{prop_name} is else: #{m.return_type}"
						end
					end
					#type = nil
					#contains_one_uni prop_name, type
				end
			end
		end
	end


	PROP_ADAPTERS = Hash.new {|h,k| h[k] = {} }

	private

	def self.property_name(java_method)
		return java_method.name.remove_prefix('get').proper_uncapitalize if java_method.name.start_with?('get')
		return java_method.name.remove_prefix('is').proper_uncapitalize if java_method.name.start_with?('is')
	end

  	def self.get_generic_param(generic_str)
  		return generic_str.remove_prefix('public java.util.List<') if generic_str.start_with?('public java.util.List<')
  		return generic_str.remove_prefix('public final java.util.List<') if generic_str.start_with?('public final java.util.List<')
  		nil
  	end

  	wrap [
  		'Comment',
  		'BlockComment',  		
  		'LineComment',
  		'ImportDeclaration',
  		'CompilationUnit',
	  	'TypeParameter',
	  	'PackageDeclaration',
	  	
	  	'body.BodyDeclaration',	  	
	  	'body.TypeDeclaration',
  		'body.AnnotationDeclaration',
  		'body.AnnotationMemberDeclaration',
	  	'body.JavadocComment',	  	
  		'body.VariableDeclaratorId',
	  	'body.Parameter',
	  	'body.MethodDeclaration',
	  	'body.ClassOrInterfaceDeclaration',
	  	'body.EmptyMemberDeclaration',
	  	'body.EmptyTypeDeclaration',
	  	'body.EnumConstantDeclaration',
	  	'body.EnumDeclaration',
	  	'body.FieldDeclaration',
	  	'body.InitializerDeclaration',
	  	'body.ConstructorDeclaration',
	  	'body.VariableDeclarator',

  		'expr.Expression',
  		'expr.NameExpr',  		
	  	'expr.AnnotationExpr',
		'expr.ArrayAccessExpr',
		'expr.ArrayCreationExpr',
		'expr.ArrayInitializerExpr',
		'expr.AssignExpr',
		'expr.BinaryExpr',
		'expr.LiteralExpr',
		'expr.BooleanLiteralExpr',
		'expr.CastExpr',
		'expr.StringLiteralExpr',
		'expr.CharLiteralExpr',
		'expr.ClassExpr',
		'expr.ConditionalExpr',
		'expr.DoubleLiteralExpr',
		'expr.EnclosedExpr',
		'expr.FieldAccessExpr',
		'expr.InstanceOfExpr',
		'expr.IntegerLiteralExpr',
		'expr.IntegerLiteralMinValueExpr',
		'expr.LongLiteralExpr',
		'expr.LongLiteralMinValueExpr',
		'expr.MarkerAnnotationExpr',
		'expr.MemberValuePair',
		'expr.MethodCallExpr',
		'expr.NormalAnnotationExpr',
		'expr.NullLiteralExpr',
		'expr.ObjectCreationExpr',
		'expr.QualifiedNameExpr',
		'expr.SingleMemberAnnotationExpr',
		'expr.SuperExpr',
		'expr.ThisExpr',
		'expr.UnaryExpr',
		'expr.VariableDeclarationExpr',

	  	'stmt.Statement',
	  	'stmt.BlockStmt',
		'stmt.AssertStmt',
		'stmt.BreakStmt',
		'stmt.CatchClause',
		'stmt.ContinueStmt',
		'stmt.DoStmt',
		'stmt.EmptyStmt',
		'stmt.ExplicitConstructorInvocationStmt',
		'stmt.ExpressionStmt',
		'stmt.ForeachStmt',
		'stmt.ForStmt',
		'stmt.IfStmt',
		'stmt.LabeledStmt',
		'stmt.ReturnStmt',
		'stmt.SwitchEntryStmt',
		'stmt.SwitchStmt',
		'stmt.SynchronizedStmt',
		'stmt.ThrowStmt',
		'stmt.TryStmt',
		'stmt.TypeDeclarationStmt',
		'stmt.WhileStmt',

	  	'type.Type',
	  	'type.ClassOrInterfaceType',
	  	'type.PrimitiveType',
	  	'type.ReferenceType',
	  	'type.VoidType',
	  	'type.WildcardType' ]

	['Or','And','BinOr','BinAnd', 'Xor',
		'Equals','NotEquals',
		'Less','Greater','LessEquals','GreaterEquals',
		'LShift','RSignedShift','RUnsignedShift',
		'Plus', 'Minus', 'Times','Divide','Remainder'].each do |op|
		c = Class.new(BinaryExpr)
		Java.const_set "#{op}BinaryExpr", c
	end
	
	class InterfaceMethodDeclaration < MethodDeclaration
	end

	class ClassMethodDeclaration < MethodDeclaration
	end

end
end