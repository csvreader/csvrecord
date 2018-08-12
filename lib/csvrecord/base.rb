# encoding: utf-8


module CsvRecord

  ## note on naming:
  ##   use naming convention from awk and tabular data package/json schema for now
  ##    use - records  (use rows for "raw" untyped (string) data rows )
  ##        - fields  (NOT columns or attributes) -- might add an alias later - why? why not?

  class Field  ## ruby record class field
    attr_reader :name, :type

    def initialize( name, type )
      ## note: always symbol-ify (to_sym) name and type

      ## todo: add title or titles for header field/column title as is e.g. 'Team 1' etc.
      ##   incl. numbers only or even an empty header title
      @name = name.to_sym

      if type.is_a?( Class )
        @type = type    ## assign class to its own property - why? why not?
      else
        @type = Type.registry[type.to_sym]
        if @type.nil?
          puts "!!!! warn unknown type >#{type}< - no class mapping found; add missing type to CsvRecord::Type.registry[]"
          ## todo: fix raise exception!!!!
        end
      end
    end
  end  # class Field



  class Type   ## todo: use a module - it's just a namespace/module now - why? why not?

    ##  e.g. use Type.registry[:string] = String etc.
    ##   note use @@ - there is only one registry
    def self.registry() @@registry ||={} end

    ## add built-in types:
    registry[:string]  = String
    registry[:integer] = Integer   ## todo/check: add :number alias for integer? why? why not?
    registry[:float]   = Float
    ## todo: add some more
  end  # class Type



  def self.define( &block )
    builder = Builder.new
    if block.arity == 1
      block.call( builder )
      ## e.g. allows "yield" dsl style e.g.
      ##  CsvRecord.define do |rec|
      ##     rec.string :team1
      ##     rec.string :team2
      ##  end
      ##
    else
      builder.instance_eval( &block )
      ## e.g. shorter "instance eval" dsl style e.g.
      ##  CsvRecord.define do
      ##     string :team1
      ##     string :team2
      ##  end
    end
    builder.to_record
  end



class Base

def self.fields   ## note: use class instance variable (@fields and NOT @@fields)!!!! (derived classes get its own copy!!!)
  @fields ||= []
end

def self.field_names   ## rename to header - why? why not?
  ## return header row, that is, all field names in an array
  ##   todo: rename to field_names or just names - why? why not?
  ##  note: names are (always) symbols!!!
  fields.map {|field| field.name }
end

def self.field_types
  ##  note: types are (always) classes!!!
  fields.map {|field| field.type }
end



def self.field( name, type=:string )
  field = Field.new( name, type )
  fields << field

  define_field( field )  ## auto-add getter,setter,parse/typecast
end

def self.define_field( field )
  name = field.name   ## note: always assumes a "cleaned-up" (symbol) name
  type = field.type   ## note: always assumes a (class) type

  define_method( name ) do
    instance_variable_get( "@#{name}" )
  end

  define_method( "#{name}=" ) do |value|
    instance_variable_set( "@#{name}", value )
  end

  define_method( "parse_#{name}") do |value|
    instance_variable_set( "@#{name}", self.class.typecast( value, type ) )
  end
end

## column/columns aliases for field/fields
##   use self <<  with alias_method  - possible? works? why? why not?
def self.column( name, type=:string ) field( name, type ); end
def self.columns() fields; end
def self.column_names() field_names; end
def self.column_types() field_types; end



def self.typecast( value, type )  ## cast (convert) from string value to type (e.g. float, integer, etc.)


  ## convert string value to (field) type
  if type == String
     value   ## pass through as is
  elsif type == Float
    ## note: allow/check for nil values - why? why not?
    float = (value.nil? || value.empty?) ? nil : value.to_f
    puts "typecast >#{value}< to float number >#{float}<"
    float
  elsif type == Integer
    number = (value.nil? || value.empty?) ? nil : value.to_i(10)   ## always use base10 for now (e.g. 010 => 10 etc.)
    puts "typecast >#{value}< to integer number >#{number}<"
    number
  else
    ## raise exception about unknow type
    pp type
    puts "!!!! unknown type >#{type}< - don't know how to convert/typecast string value >#{value}<"
    value
  end
end


def self.build_hash( values )   ## find a better name - build_attrib? or something?
  ## convert to key-value (attribute) pairs
  ## puts "== build_hash:"
  ## pp values

  ## e.g. [[],[]]  return zipped pairs in array as (attribute - name/value pair) hash
  Hash[ field_names.zip(values) ]
end



def parse( values )   ## use read (from array) or read_values or read_row - why? why not?

  ## todo/fix:
  ##  check if values is a string
  ##  use Csv.parse_line to convert to array
  ##  otherwise assume array of (string) values

  h = self.class.build_hash( values )
  update( h )
end

def to_a
  ## return array of all record values (typed e.g. float, integer, date, ..., that is,
  ##   as-is and  NOT auto-converted to string
  ##  use to_csv or values for all string values)
  self.class.fields.map { |field| send( field.name ) }
end

def to_h    ## use to_hash - why? why not?  - add attributes alias - why? why not?
  self.class.build_hash( to_a )
end


def values   ## use/rename/alias to to_row too - why? why not?
  ## todo/fix: check for date and use own date to string format!!!!
  to_a.map{ |value| value.to_s }
end
## use values as to_csv alias
## - reverse order? e.g. make to_csv an alias of value s- why? why not?
alias_method :to_csv, :values



def self.parse( txt_or_rows )  ## note: returns an (lazy) enumarator
  if txt_or_rows.is_a? String
    txt = txt_or_rows
    rows = CSV.parse( txt, headers: true )
  else
    ### todo/fix: use only self.create( array-like ) for array-like data  - why? why not?
    rows = txt_or_rows    ## assume array-like records that responds to :each
  end

  pp rows

  Enumerator.new do |yielder|
    rows.each do |row|
     ## check - check for to_h - why? why not?  supported/built-into by CSV::Row??
     ## if row.respond_to?( :to_h )
     ## else
       ## pp row.fields
       ## pp row.to_hash
       ## fix/todo!!!!!!!!!!!!!
       ##  check for CSV::Row etc. - use row.to_hash ?
       h = build_hash( row.fields )
       ## pp h
       rec = new( h )
     ## end
     yielder.yield( rec )
    end
  end
end


def self.read( path )  ## not returns an enumarator
  txt  = File.open( path, 'r:utf-8' ).read
  parse( txt )
end



def initialize( **kwargs )
  update( kwargs )
end

def update( **kwargs )
  pp kwargs
  kwargs.each do |name,value|
    ## note: only convert/typecast string values
    if value.is_a?( String )
      send( "parse_#{name}", value )  ## note: use parse_<name> setter (for typecasting)
    else  ## use "regular" plain/classic attribute setter
      send( "#{name}=", value )
    end
  end

  ## todo: check if args.first is an array  (init/update from array)
  self   ## return self for chaining
end

end # class Base
end # module CsvRecord
