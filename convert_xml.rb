# PatternPedia
# 
# Copyright (c) Norbert Fürst, Daniel Willig, Adam Grahovac. All rights reserved.
# 
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 3.0 of the License, or (at your option) any later version.
# 
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
# 
# You should have received a copy of the GNU Lesser General Public
# License along with this library.

#!/usr/bin/env ruby
require 'nokogiri'
require 'optparse'

VERSION = '0.0.3'

#
## optparse is used for managing command line parameters
##
options = {}

opt_parser = OptionParser.new do |opts|
  opts.banner = 'Usage: convert_xml [OPTIONS]'
  opts.separator ''
  opts.separator 'Commands'
  opts.on('-v', 'Run verbosely') do |v|
    options[:verbose] = v
  end

  opts.on('-i', '--input-file FILE', 'The file that needs to be converted') do |i|
    options[:input_file] = i
  end

  opts.on('-o', '--output-file FILE', 'The file the converted XMl will be written to') do |i|
    options[:output_file] = i
  end

  opts.on('-c','--common-js-file FILE','The file the common.js will be written to') do |i|
    options[:common_js_file] = i
  end
  
  opts.on('-m','--mainpage-file FILE','The file the mainpage will be written to') do |i|
    options[:mainpage_file] = i
  end

  opts.on_tail('-h', '--help', 'Show this message') do
    puts opts
    exit
  end

  opts.on_tail('--version', 'Show version') do
    puts VERSION
    exit
  end
end

opt_parser.parse!
mandatory_args = [:input_file, :output_file, :common_js_file, :mainpage_file]
missing_args = mandatory_args.select { |param| options[param].nil? }

begin
  unless missing_args.empty?
    puts "Missing options: #{missing_args.join(', ')}"
    puts opt_parser
    exit
  end
rescue OptionParser::InvalidOption, OptionParser::MissingArgument #
  puts $!.to_s # Friendly output when parsing fails
  puts optparse #
  exit
end

class String
  
  def remove_newlines
  	self.gsub("\n", " ").gsub("\t", "").gsub(/ ([,.;:])/, '\1')
  end
  
  def prettify
  	self.gsub("-", " ").split(" ").map(&:capitalize).join(" ")
  end
  
  def camel_case_to_minus_split
  	self.split(/(?=[A-Z])/).map(&:uncapitalize).join('-')
  end
  
  def uncapitalize 
    self[0, 1].downcase + self[1..-1]
  end
  
  def replace_forbidden_xml_chars
  	self.gsub("&", "&amp;").gsub(/</, "&lt;").gsub(/>/, "&gt;").gsub("\"", "&quot;").gsub("\'", "&apos;")  	
  end

  def ul_list
  	self.strip.split('[[').reject(&:empty?).map { |li| "* [[#{li.strip}" }.join("\n")
  end

end

class MediaWiki
  def self.render(name, pages)
    document = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"
    .+ "<mediawiki xmlns=\"http://www.mediawiki.org/xml/export-0.8/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:schemaLocation=\"http://www.mediawiki.org/xml/export-0.8/ http://www.mediawiki.org/xml/export-0.8.xsd\" version=\"0.8\" xml:lang=\"en\">\n"
    .+ "\n"
    .+ "<siteinfo>\n"
    .+ "<sitename>#{name}</sitename>\n"
    .+ "<base>-</base>\n"
    .+ "<generator>PCT</generator>\n"
    .+ "<case>first-letter</case>\n"
    .+ "</siteinfo>\n"
    .+ "\n" 
    pages.each do |page|
    	document += page.render
    end
    document += "</mediawiki>"
  end
end

class Page
	attr_accessor :name, :text
	
	def render
		page = "<page>\n"
		.+ "<title>#{self.name}</title>\n"
		.+ "<id />\n"
		.+ "<restrictions />\n"
		.+ "<revision>\n"
		.+ "<id />\n"
		.+ "<timestamp />\n"
		.+ "<comment />\n"
		.+ "<text xml:space=\"default\">\n"
		.+ "#{self.text.replace_forbidden_xml_chars}\n"
		.+ "</text>\n"
		.+ "<model>wikitext</model>\n"
		.+ "<format>text/x-wiki</format>\n"
		.+ "</revision>\n"
		.+ "</page>\n"
		.+ "\n"
	end
end

class Category < Page
  attr_accessor :parent, :raw_text
  
  def name_without_prefix
  	name.gsub('Category:', '')
  end
  
  def text
  	category_text = self.raw_text
    if !self.parent.empty?
    	category_text += "[[Category:" + self.parent + "]]"
    end
    category_text
  end
  
end

class Property < Page
  attr_accessor :type, :raw_text
  
  def text
  	property_text = self.raw_text
    property_text += "[[Has type::" + self.type + "| ]]"
  end
  
  def name_without_prefix
  	name.gsub('Property:', '')
  end
  
end

class Pattern < Page
  attr_accessor :category, :sections
  
  def text
  	pattern_text = "{{Pattern"
    self.sections.each do |section|
      pattern_text += "\n|" + section.name + "=\n"
      if !section.text.nil?
				section_text = section.text
				if section.render_ul
					section_text = section_text.ul_list
				end
				pattern_text += section_text
			end
    end
    pattern_text += "\n}}"
  end
end

class Pattern_Template < Page
	
	attr_accessor :sections, :properties
		
	def initialize(sections, properties)
		@sections = sections
		@properties = properties
	end
	
	def name
		'Template:Pattern'
	end
	
	def text
		pattern_template_text = render_noinclude
		.+ "<includeonly>\n"
		.+ "__NOTOC__\n"
		.+ "<div class=\"pattern\">\n"
  	.+ "\n"
		
		rendered_sections = []
			
		if sections.include_section?('intent') and sections.include_section?('icon') and sections.include_section?('question')
			pattern_template_text += render_classic_layout
			rendered_sections << 'intent'
			rendered_sections << 'question'
			rendered_sections << 'icon'
		elsif sections.include_section?('icon') and sections.include_section?('short-solution')
			pattern_template_text += render_igbpp_layout
			rendered_sections << 'icon'
			rendered_sections << 'short-solution'
		elsif sections.include_section?('intent') and sections.include_section?('icon') and !sections.include_section?('question')
			pattern_template_text += render_classic_layout_without_question
			rendered_sections << 'icon'
			rendered_sections << 'intent'
		elsif !sections.include_section?('intent') and sections.include_section?('icon') and sections.include_section?('question')
			pattern_template_text += render_classic_layout_without_intent
			rendered_sections << 'question'
			rendered_sections << 'icon'
		end
		
		pattern_template_text += "#{render_missing_sections(rendered_sections)}"
		.+ "<div class=\"hidden\" id=\"reference-data\">\n"
		.+ "#{render_properties_in_template}"
		.+ "</div>\n"
		.+ "\n"
		.+ "</div>\n"
		.+ "[[Category:{{{category}}}]]\n"
		.+ "</includeonly>\n"
	end
	
	private
	def render_noinclude
  	noinclude = "<noinclude>\n"
  	.+ "This is the \"Pattern\" template. It should be called in the following format:\n"
  	.+ "<pre>\n"
		
		# The method that is used to render patterns for the xml (that is used for
		# Special:Import) is used here with no text inside the sections, so that users, who
		# look into the Template:Pattern know how the template has to be used.
		pattern_dummy = Pattern.new
		pattern_dummy.sections = sections
  	noinclude += pattern_dummy.text
  	.+ "\n"
  	.+ "</pre>\n"
  	.+ "Edit the page to see the template text.\n"
  	.+ "</noinclude>\n"
  end
  
  ## render_classic_layout
  #
  # renders the layout that was used for http://www.cloudcomputingpatterns.org
 	#
  # |-----------------|------------|
  # |     intent      | References |
  #	|------|----------|            |
  # | icon | question |            |
  # |------|----------|------------|
  #
  def render_classic_layout
  	classic_layout = "<div class=\"row\">\n"
		.+ "<div class=\"col-lg-8\">\n"
		.+ "<div class=\"row\">\n"
		.+ "<div class=\"col-lg-12\">\n"
		.+ "<div class=\"intent well well-lg\">{{{intent}}}</div>\n"
		.+ "</div>\n"
		.+ "</div>\n"
		.+ "<div class=\"row\" style=\"margin-bottom:20px;\">\n"
		.+ "<div class=\"col-lg-3\">\n"
		.+ "<div>[[File:{{{icon}}}|118px]]</div>\n"
		.+ "</div>\n"
		.+ "<div class=\"col-lg-9 question-wrapper\">\n"
		.+ "<div class=\"question\">\n"
		.+ "<div class=\"text\">{{{question}}}</div>\n"
		.+ "</div>\n"
		.+ "</div>\n"
		.+ "</div>\n"
		.+ "</div>\n"
		.+ "<div class=\"col-lg-4\">\n"
		.+ "#{render_references}"
		.+ "</div>\n"
		.+ "</div>\n"
		.+ "\n"
  end
  
  ## render_igbpp_layout
  #
  # renders the layout that was used for "TR-2013-05 Implicit_Green_Patterns.pdf"
  #
  #	|------|----------|------------|
  # | icon | shrt-sol | References |
  # |------|----------|------------|
  #
  def render_igbpp_layout
    igbpp_layout = "<div class=\"row\">\n"
		.+ "<div class=\"col-lg-8\">\n"
		.+ "<div class=\"row\" style=\"margin-bottom:20px;\">\n"
		.+ "<div class=\"col-lg-3\">\n"
		.+ "<div>[[File:{{{icon}}}|118px]]</div>\n"
		.+ "</div>\n"
		.+ "<div class=\"col-lg-9 question-wrapper\">\n"
		.+ "<div class=\"question\">\n"
		.+ "<div class=\"text\">{{{short-solution}}}</div>\n"
		.+ "</div>\n"
		.+ "</div>\n"
		.+ "</div>\n"
		.+ "</div>\n"
		.+ "<div class=\"col-lg-4\">\n"
		.+ "#{render_references}"
		.+ "</div>\n"
		.+ "</div>\n"
		.+ "\n"
	end
  
   
	## render_classic_layout_without_intent
  #
  # renders the layout that was used for http://www.cloudcomputingpatterns.org
  # with the following changes:
  # * 'intent' is removed
  #
  #	|------|----------|------------|
  # | icon | question | References |
  # |------|----------|------------|
  #
  def render_classic_layout_without_intent
    classic_layout_without_intent = "<div class=\"row\">\n"
		.+ "<div class=\"col-lg-8\">\n"
		.+ "<div class=\"row\" style=\"margin-bottom:20px;\">\n"
		.+ "<div class=\"col-lg-3\">\n"
		.+ "<div>[[File:{{{icon}}}|118px]]</div>\n"
		.+ "</div>\n"
		.+ "<div class=\"col-lg-9 question-wrapper\">\n"
		.+ "<div class=\"question\">\n"
		.+ "<div class=\"text\">{{{question}}}</div>\n"
		.+ "</div>\n"
		.+ "</div>\n"
		.+ "</div>\n"
		.+ "</div>\n"
		.+ "<div class=\"col-lg-4\">\n"
		.+ "#{render_references}"
		.+ "</div>\n"
		.+ "</div>\n"
		.+ "\n"
  end
  
  ## render_classic_layout_without_question
  #
  # renders the layout that was used for http://www.cloudcomputingpatterns.org
  # with the following changes:
  # * 'question' is removed
  # * 'intent' is at the spot, that was used for 'question'
  #
  #	|------|----------|------------|
  # | icon |  intent  | References |
  # |------|----------|------------|
  #
  def render_classic_layout_without_question
    classic_layout_without_question = "<div class=\"row\">\n"
		.+ "<div class=\"col-lg-8\">\n"
		.+ "<div class=\"row\" style=\"margin-bottom:20px;\">\n"
		.+ "<div>\n"
		.+ "<div class=\"icon\">[[File:{{{icon}}}|118px]]</div>\n"
		.+ "</div>\n"
		.+ "<div class=\"col-lg-9 question-wrapper\">\n"
		.+ "<div class=\"intent well well-lg\">\n"
  	.+ "{{{intent}}}\n"
  	.+ "</div>\n"
		.+ "</div>\n"
		.+ "</div>\n"
		.+ "</div>\n"
		.+ "<div class=\"col-lg-4\">\n"
		.+ "#{render_references}"
		.+ "</div>\n"
		.+ "</div>\n"
		.+ "\n"
  
  end
  
  def render_references

  	references = "<div class=\"infobox panel panel-default\">\n"
  	.+ "<div class=\"panel-heading\">References</div>\n"
  	.+ "<div class=\"panel-body\">\n"
  	.+ "<div class=\"row\">\n"
  	.+ "<div class=\"col-lg-12\">\n"
  	
  	properties.each do |property|
  		references += "<div id=\"#{property.name_without_prefix.camel_case_to_minus_split}-info-section\">\n"
			.+ "<h5>#{property.name_without_prefix.camel_case_to_minus_split.prettify}</h5>\n"
			.+ "<ul id=\"#{property.name_without_prefix.camel_case_to_minus_split}-list\"></ul>\n"
			.+ "</div>\n"
  	end
  	
  	references += "\n"
  	.+ "</div>\n"
  	.+ "</div>\n"
  	.+ "</div>\n"
  	.+ "</div>\n"
  end
  
  def render_icon_next_to_intent
    icon_next_to_intent = "<div class=\"row\" style=\"margin-bottom:20px;\">\n"
    .+ "<div class=\"col-lg-3\">\n"
    .+ "<div>\n"
    .+ "[[File:{{{icon}}}|118px]]\n"
    .+ "</div>\n"
    .+ "</div>\n"
    .+ "<div class=\"question-wrapper col-lg-8\">\n"
  	.+ "<div class=\"intent well well-lg\">\n"
  	.+ "{{{intent}}}\n"
  	.+ "</div>\n"
    .+ "</div>\n"
    .+ "</div>\n"
    .+ "\n"
  end
  
  def render_missing_sections(rendered_sections)
  	missing_sections = ""
		sections.each do |section|
			if !rendered_sections.include?(section.name)
				case section.name
					when 'category'
					when 'icon'
						missing_sections += "<div style=\"margin-bottom:20px;\">\n"
						.+ "[[File:{{{icon}}}|118px]]\n"
						.+ "</div>\n"
						.+ "\n"
					else
						missing_sections += "<div class=\"panel panel-default\">\n"
						.+ "<div class=\"panel-heading\">#{section.name.prettify}</div>\n"
						.+ "<div class=\"panel-body\">\n"
						.+ "{{{#{section.name}}}}\n"
						.+ "</div>\n"
						.+ "</div>\n"
						.+ "\n"
				end
			end
		end
		missing_sections
	end
	
	def render_properties_in_template
		properties_in_template = ""
		properties.each do |property|
			properties_in_template += "<div id=\"#{property.name_without_prefix.camel_case_to_minus_split}-data\">{{#show: {{FULLPAGENAME}} |?#{property.name_without_prefix} |format=array|link=subject}}</div>\n"
		end
		properties_in_template
	end
	
end

class Tree_Renderer < Page

	attr_accessor :categories, :patterns
	
	def initialize(categories, patterns)
		@categories = categories
		@patterns = patterns
	end

	private
  def tree
		if @tree.nil?
			@tree = {}
			@tree_debth = 0
			
			# we ignore the real root category for the sidebar generation, because just
  		# 3 levels of elements of the category-pattern tree are renderable.
				
			level1_elements = @categories.select{|category| category.parent == @categories.first.name_without_prefix}.map(&:name_without_prefix)
			level1_elements += @patterns.select{|pattern| pattern.category == @categories.first.name_without_prefix}.map(&:name)
			if !level1_elements.empty? and @tree_debth <= 0
				@tree_debth = 1
			end

			level1_elements.each do |l1e|
				level2_elements = @categories.select{|category| category.parent == l1e}.map(&:name_without_prefix)
				level2_elements += @patterns.select{|pattern| pattern.category == l1e}.map(&:name)
				if !level2_elements.empty? and @tree_debth <= 1
					@tree_debth = 2
				end
				level2_tree = {}
				level2_elements.each do |l2e|
					level3_elements = @categories.select{|category| category.parent == l2e}.map(&:name_without_prefix)
					level3_elements += @patterns.select{|pattern| pattern.category == l2e}.map(&:name)
					if !level3_elements.empty? and @tree_debth <= 2
						@tree_debth = 3
					end
					level2_tree[l2e] = level3_elements
				end
				@tree[l1e] = level2_tree
			end
		else
			@tree
		end		
	end
	
	def tree_debth
		if @tree_debth.nil?
			tree
		end
		if @tree_debth.nil?
			puts 'tree cannot be generated'
		else
			@tree_debth
		end
	end
	
end

class Sidebar < Tree_Renderer

	def name
		'Bootstrap:Sidebar'
	end
	
	def text
		case tree_debth
			when 1
				render_level1_sidebar
			when 2
				render_level2_sidebar
			when 3
				render_level3_sidebar
		end
  end  
  
  private
  def render_level3_sidebar

   	level3_sidebar = ""
  	
  	tree.each_pair do |root_category, sub_categories|
  		random_number = rand(9999999999999)
  		level3_sidebar += "<div class=\"panel panel-default sidebar-element\">\n"
  		.+ "<div class=\"panel-heading\" data-toggle=\"collapse\" data-target=\"##{random_number.to_s}>\n"
  		.+ "#{root_category}\n"
  		.+ "</div>\n"
  		.+ "<div class=\"panel-body collapse in\" id=\"#{random_number.to_s}>\n"
  		
  		sub_categories.each_pair do |sub_category, patterns_of_category|
  			level3_sidebar += "* [[:Category:" + sub_category + " | " + sub_category + "]]\n"
  			patterns_of_category.each do |pattern|
  				level3_sidebar += "** [[" + pattern + "]]\n"
  			end
  		end
  		
  		level3_sidebar += "</div>\n"
  		level3_sidebar += "</div>\n"
  	end
  	level3_sidebar

  end
  
  def render_level2_sidebar
    level2_sidebar = ""
  	tree.each_pair do |category, patterns|
  		random_number = rand(9999999999999)
  		level2_sidebar += "<div class=\"panel panel-default sidebar-element\">\n"
  		.+ "<div class=\"panel-heading\" data-toggle=\"collapse\" data-target=\"##{random_number.to_s}>\n"
  		.+ "#{category}\n"
  		.+ "</div>\n"
  		.+ "<div class=\"panel-body collapse in\" id=\"#{random_number.to_s}>\n"
  		patterns.each_pair do |pattern, empty|
  			level2_sidebar += "* [[#{pattern}]]\n"
  		end
  		level2_sidebar += "</div>\n"
  		level2_sidebar += "</div>\n"
  	end
  	level2_sidebar
  end
  
  def render_level1_sidebar
		random_number = rand(9999999999999)
		level1_sidebar = "<div class=\"panel panel-default sidebar-element\">\n"
		.+ "<div class=\"panel-heading\" data-toggle=\"collapse\" data-target=\"##{random_number.to_s}>\n"
		.+ "#{categories.first.name_without_prefix}\n"
		.+ "</div>\n"
		.+ "<div class=\"panel-body collapse in\" id=\"#{random_number.to_s}>\n"
  	tree.each_pair do |pattern, empty|
			level1_sidebar += "* [[#{pattern}]]\n"
  	end
  	level1_sidebar += "</div>\n"
  	level1_sidebar += "</div>\n"
  end
end

class Custom_Mainpage < Tree_Renderer

	def name
		categories.first.name_without_prefix
	end
	
	def text
		mainpage_text = "__NOTOC__ __NOEDITSECTION__\n"
		.+ categories.first.text + "\n"
		case tree_debth
			when 1
				mainpage_text += render_level1_mainpage
			when 2
				mainpage_text += render_level2_mainpage
			when 3
				mainpage_text += render_level3_mainpage
		end
		mainpage_text
	end
	
	private
	def render_level3_mainpage
		pattern_tables = ""
		tree.each_pair do |category, sub_categories|
			pattern_tables += "== #{category} ==\n"
			pattern_tables += "{|\n"
			pattern_counter = 0
			sub_categories.each_pair do |sub_category, pattern_names|
				pattern_names.each do |pattern|
					pattern_tables += "| align=\"center\" width=16,666%|[[File:#{patterns.pattern_icon_for_name(pattern)}|100px|center|link=#{pattern}]][[#{pattern}|#{pattern}]]\n"
					pattern_counter += 1
					if pattern_counter == 6
						pattern_counter = 0
						pattern_tables += "|-\n"
					end
				end
			end
			pattern_tables += "|}\n"
		end
		pattern_tables
	end
	
	def render_level2_mainpage
		pattern_tables = ""
		tree.each_pair do |category, pattern_names|
			pattern_tables += "== #{category} ==\n"
			pattern_tables += "{|\n"
			pattern_counter = 0
			pattern_names.each_pair do |pattern, empty|
				pattern_tables += "| align=\"center\" width=16,666%|[[File:#{patterns.pattern_icon_for_name(pattern)}|100px|center|link=#{pattern}]][[#{pattern}|#{pattern}]]\n"
				pattern_counter += 1
				if pattern_counter == 6
					pattern_counter = 0
					pattern_tables += "|-\n"
				end
			end
			pattern_tables += "|}\n"
		end
		pattern_tables
	end
	
	def render_level1_mainpage
		pattern_table = ""
		pattern_counter = 0
		tree.each_pair do |pattern_name, empty|
			pattern_table += "{|\n"
			pattern_table += "| align=\"center\" width=16,666%|[[File:#{patterns.pattern_icon_for_name(pattern_name)}|100px|center|link=#{pattern_name}]][[#{pattern_name}|#{pattern_name}]]\n"
			pattern_counter += 1
			if pattern_counter == 6
				pattern_counter = 0
				pattern_table += "|-\n"
			end
			pattern_table += "|}\n"
		end
		pattern_table
	end
end

class MediaWiki_Mainpage < Page

	attr_accessor :categories

	def initialize(categories)
		@categories = categories
	end

	def name
		'MediaWiki:Mainpage'
	end
	
	def text
		categories.first.name_without_prefix
	end
	
end

class Common_Js < Page

	attr_accessor :properties, :addon_name
	
	def initialize(properties, addon_name)
		@properties = properties
		@addon_name = addon_name
	end
	
	def name
		'MediaWiki:Common.js'
	end
	
	def text
		common_js = "/* Any JavaScript here will be loaded for all users on every page load. */\n"
		.+ "\n"
		
		property_names = []
		properties.each do |property|
			property_names << property.name_without_prefix
		end
		
		property_names.each do |property_name|
			common_js += "var #{property_name.uncapitalize}Data = $('#reference-data ##{property_name.camel_case_to_minus_split}-data').children();\n"
			.+ "\n"
			.+ "$.each(#{property_name.uncapitalize}Data, function(index, element) {\n"
			.+ "if (element == \"\")\n"
			.+ "return;\n"
			.+ "var li = $(\"<li />\").append(element);\n"
			.+ "$('##{property_name.camel_case_to_minus_split}-list').append(li);\n"
			.+ "});\n"
			.+ "\n"
			.+ "if ($('##{property_name.camel_case_to_minus_split}-list li').length == 0)\n"
			.+ "$('##{property_name.camel_case_to_minus_split}-info-section').addClass('hidden');\n"
			.+ "\n"
			.+ "\n"
		end
		
		addon_file = File.open(addon_name, 'r')
		common_js += addon_file.read
		addon_file.close
		
		common_js
	end
end

class Section
  attr_accessor :name, :text, :render_ul
  def initialize(name, render_ul)
  	@name = name
  	@render_ul = render_ul
  end
end

class Category_Container < Array
  def initialize(nokogiri)
    origin_categories = nokogiri.css('patternrepository categories category')
    origin_categories.each do |cat|
      self << self.class.parse_category(cat)
    end
  end
  
  def include_category?(category_name)
  	does_exist = false
  	self.each do |category|
  		if category.name == "Category:" + category_name
  			does_exist = true
  		end
  	end
  	does_exist
  end

  private
  def self.parse_category(category)
    cat = Category.new
    cat.name = "Category:" + category.css('name').text
    cat.raw_text = category.css('description').text.gsub(/\s+/, ' ').strip
    cat.parent = category.css('parent').text
    cat
  end

end

class Property_Container < Array
  def initialize(nokogiri)
    origin_properties = nokogiri.css('patternrepository properties property')
    origin_properties.each do |property|
      self << self.class.parse_property(property)
    end
  end

  private
  def self.parse_property(property)
    prop = Property.new
    prop.name = "Property:" + property.css('name').text
    prop.type = property.css('type').text
    prop.raw_text = property.css('description').text.gsub(/\s+/, ' ').strip
    prop
  end
end

class Pattern_Container < Array
  def initialize(nokogiri, sections, categories)
    origin_patterns = nokogiri.css('patternrepository patterns pattern')
    origin_patterns.each do |pattern|
      self << self.class.parse_pattern(pattern, sections, categories)
    end
  end
  
  def pattern_icon_for_name(name)
  	pattern_icon = ""
  	self.each do |pattern|
  		if pattern.name == name
  			pattern.sections.each do |section|
  				if section.name == "icon"
  					pattern_icon = section.text
  				end
  			end
  		end
  	end
  	pattern_icon
  end

  private
  def self.parse_pattern(pattern, sections, categories)
  
		pat = Pattern.new
	
		pat.name = pattern.css('name').text
		pat.category = pattern.css('category').text
		pat.sections = sections.copy
		
		pat.sections.each do |section|
			access_string = ""
			case section.name
				when 'context'
					access_string = "patternsection[@name='Context']"
				when 'solution'
					access_string = "patternsection[@name='Solution']"
				when 'related-patterns'
					access_string = "patternsection[@name='Related Patterns']"
				when 'consider-next'
					access_string = "globallinks"
				else
					access_string = section.name
			end
			section.text = extract_section(pattern.css(access_string), categories)
			if section.text == ""
				section.text = extract_section(pattern.css(section.name), categories)
			end
			section.text = section.text.remove_newlines
		end  
    pat
  end

  def self.extract_section(section_node, categories)
    result = ''
    section_node.children.each do |child|
      case child
        when Nokogiri::XML::Text
          result += child.text
        when Nokogiri::XML::Element
          case child.name
            when 'link'
              type = child.attribute('type')
              text = child.text.strip
              target = child.attribute('target') || text
              if categories.include_category?(target)
              	target = "Category:#{target.to_s}"
              end
              link = "[[#{type}::#{target.to_s}|#{text}]]"
            when 'image'
              link = "[[File:#{child.text.strip}|850px]]"
          end
          result += link
      end
    end
    result
  end
  
end

class Section_Container < Array

	def self.new_from_section_files(sections_file, ul_rendered_file)
	  
	  available_sections_names = []
    ul_rendered_sections_names = []
    
    File.readlines(sections_file).each do |line|
      available_sections_names << line.gsub("\n", "").gsub("\r", "")
    end
    File.readlines(ul_rendered_file).each do |line|
      ul_rendered_sections_names << line.gsub("\n", "").gsub("\r", "")
    end
	  
		new_container = Section_Container.new
		available_sections_names.each do |sec|
			new_container << Section.new(sec, ul_rendered_sections_names.include?(sec))
		end
		new_container
	end
	
	def copy
		new_container = Section_Container.new
		self.each do |section|
			new_container << Section.new(section.name, section.render_ul)
		end
		new_container
	end
	
	def include_section?(section_name)
		does_exist = false
		self.each do |section|
			if section.name == section_name
				does_exist = true
			end
		end
		does_exist
	end

end		

# Read the input file and put it into a nokogiri
file = File.open(options[:input_file])
nokogiri = Nokogiri.XML(file)
file.close

# Instantiation of primary data model.
# The Primary data model is dependant on the nokogiri, the two section text files and itself.
sections = Section_Container.new_from_section_files('sections.txt', 'ul_rendered_sections.txt')
categories = Category_Container.new(nokogiri)
properties = Property_Container.new(nokogiri)
patterns = Pattern_Container.new(nokogiri, sections, categories)

# Instatiation of secondary data model.
# The secondary data model is dependant on the primary data model and the common_js_addon.
pattern_template = Pattern_Template.new(sections, properties)
sidebar = Sidebar.new(categories, patterns)
common_js = Common_Js.new(properties, 'common_js_addon.txt')
mediawiki_mainpage = MediaWiki_Mainpage.new(categories)
custom_mainpage = Custom_Mainpage.new(categories, patterns)

# Generate the MediaWiki 
# The MediaWiki is dependant on the primary and secondary data model, therefore every object of type "Page",
# except common_js and mediawiki_mainpage,
# because those Wiki-Pages do not work when automatically imported by Special:Import.
mediaWiki = MediaWiki.render(categories.first.name_without_prefix, (categories + properties + patterns) << pattern_template << sidebar << custom_mainpage)

# Write the MediaWiki-XML that is used for Special:Import 
output = File.open(options[:output_file], 'w')
output.write(mediaWiki)
output.close

# Write the file which content has to be pasted into MediaWiki:Common.js
common_js_file = File.open(options[:common_js_file], 'w')
common_js_file.write(common_js.text)
common_js_file.close

# Write the file which content has to be pasted into MediaWiki:Mainpage
mainpage_file = File.open(options[:mainpage_file], 'w')
mainpage_file.write(mediawiki_mainpage.text)
mainpage_file.close