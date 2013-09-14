module LightModels

module Java

module InfoExtraction

def self.is_camel_case_str(s)
	not s.index /[^A-Za-z0-9]/
end

def self.camel_to_words(camel)
	return [''] if camel==''

	# if camel contains an upcase word and it is followed by something then
	# extract it and process the camel before and after
	# to understand where the upcase word ends we have to look if there is
	# a downcase char after
	upcaseword_index = camel.index /[A-Z]{2}/
	number_index = camel.index /[0-9]/
	if upcaseword_index
		if upcaseword_index==0
			words_before = []
		else
			camel_before = camel[0..upcaseword_index-1]
			words_before = camel_to_words(camel_before)
		end

		camel_from = camel[upcaseword_index..-1]
		has_other_after = camel_from.index /[^A-Z]/		
		if has_other_after
			is_lower_case_after = camel_from[has_other_after].index /[a-z]/
			if is_lower_case_after
				mod = 1
			else
				mod = 0
			end
			upcase_word = camel_from[0..has_other_after-1-mod]
			camel_after = camel_from[has_other_after-mod..-1]
			words_after = camel_to_words(camel_after)
		else
			upcase_word = camel_from
			words_after = []
		end
		words = words_before
		words << upcase_word
		words = words + words_after
		words
	elsif number_index
		if number_index==0
			words_before = []
		else
			camel_before = camel[0..number_index-1]
			words_before = camel_to_words(camel_before)
		end

		camel_from = camel[number_index..-1]
		has_other_after = camel_from.index /[^0-9]/
		if has_other_after
			number_word = camel_from[0..has_other_after-1]
			camel_after = camel_from[has_other_after..-1]
			words_after = camel_to_words(camel_after)
		else
			number_word = camel_from
			words_after = []
		end
		words = words_before
		words << number_word
		words = words + words_after
		words		
	else
		camel.split /(?=[A-Z])/
	end    
end

class TermsBreaker

	attr_accessor :sequences, :inv_sequences

	def initialize
		@sequences = Hash.new {|h,k| 
			h[k] = Hash.new {|h,k| 
				h[k]=0
			} 
		}
		@inv_sequences = Hash.new {|h,k| 
			h[k] = Hash.new {|h2,k2| 
				h2[k2]=0
			} 
		}
	end

	def self.from_context(context)
		ser_context = LightModels::Serialization.jsonize_obj(context)
		values_map = LightModels::Query.collect_values_with_count(ser_context)
		instance = new		
		values_map.each do |value,c|
			value = value.to_s.strip
			if InfoExtraction.is_camel_case_str(value)
				words = InfoExtraction.camel_to_words(value)				
				first_words = words[0...-1]
				#puts "Recording that #{first_words[0]} is preceeded by #{:start} #{c} times"
				instance.inv_sequences[first_words[0].downcase][:start] += c
				first_words.each_with_index do |w,i|
					instance.sequences[w.downcase][words[i+1].downcase] += c
					instance.inv_sequences[words[i+1.downcase]][w.downcase] += c
				end
				last_word = words.last
				instance.sequences[last_word.downcase][:end] += c
			else
				# who cares, it will be never considered for composed names...
			end
		end
		instance
	end

	def frequent_straight_sequence?(w1,w2)
		w1 = w1.downcase
		w2 = w2.downcase
		all_sequences_of_w1 = 0
		@sequences[w1].each do |k,v|
			all_sequences_of_w1 += v
		end
		sequences_w1_w2 = @sequences[w1][w2]
		(sequences_w1_w2.to_f/all_sequences_of_w1.to_f)>=0.33
	end

	def frequent_inverse_sequence?(w1,w2)
		w1 = w1.downcase
		w2 = w2.downcase
		#puts "Inverse sequences of #{w1}-#{w2}"
		all_inv_sequences_of_w1 = 0
		@inv_sequences[w1].each do |k,v|
			#puts "\tpreceeded by #{k} #{v} times"
			all_inv_sequences_of_w1 += v
		end
		inv_sequences_w1_w2 = @inv_sequences[w1][w2]
		(inv_sequences_w1_w2.to_f/all_inv_sequences_of_w1.to_f)>=0.33
	end

	def frequent_sequence?(w1,w2)
		puts "Checking if #{w1}-#{w2} is freq sequence:"
		puts "\tstraight: #{frequent_straight_sequence?(w1,w2)}"
		puts "\tinverse: #{frequent_inverse_sequence?(w2,w1)}"
		frequent_straight_sequence?(w1,w2) && frequent_inverse_sequence?(w2,w1)
	end

	def terms_in_value(value)
		value = value.to_s.strip
		if InfoExtraction.is_camel_case_str(value)
			words = InfoExtraction.camel_to_words(value)
			group_words_in_terms(words).map{|w| w.downcase}			
		else
			[value]
		end
	end

	def group_words_in_terms(words)
		# getNotSoGoodFieldName is not a term because
		# notSoGoodFieldName is more frequently alone that preceded by get

		return words if words.count==1
		start_term = 0
		end_term   = 0
		term       = words[0]
		while end_term < words.count && frequent_sequence?(words[end_term],words[end_term+1])
			end_term += 1
			term += words[end_term]
		end
		return [term] if end_term==(words.count-1)
		[term] + words[end_term..-1]
	end

end

def self.terms_map(model_node,context=nil)
	# context default to root
	unless context
		context = model_node
		while context.eContainer
			context = context.eContainer
		end		
	end

	# look into context to see how frequent are certain series of words,
	# frequent series are recognized as composed terms
	terms_breaker = TermsBreaker.from_context(context)

	ser_model_node = LightModels::Serialization.jsonize_obj(model_node)
	values_map = LightModels::Query.collect_values_with_count(ser_model_node)
	terms_map = Hash.new {|h,k| h[k]=0}
	values_map.each do |v,n|
		terms_breaker.terms_in_value(v).each do |t|
			terms_map[t] += n
		end
	end
	terms_map
end

end

end

end
