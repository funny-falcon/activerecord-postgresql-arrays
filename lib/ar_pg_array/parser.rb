require 'json'

module PgArrayParser
  CURLY_BRACKETS = '{}'.freeze
  SQUARE_BRACKETS = '[]'.freeze
  NULL = 'NULL'.freeze
  NIL = 'nil'.freeze
  ESCAPE_HASH={'\\'.freeze=>'\\\\'.freeze, '"'.freeze=>'\\"'.freeze}

  def parse_numeric_pgarray(text)
    text = text.tr(CURLY_BRACKETS, SQUARE_BRACKETS)
    text.downcase!
    JSON.load(text)
  end

  def parse_safe_pgarray(text, &block)
    if text =~ /^\{([^\}]*)\}$/
      $1.split(/,\s*/).map!{|v| v == NULL ? nil : yield(v)}
    else
      raise "Mailformed array" unless text =~ /^\{\s*/
      ar, rest = _parse_safe_pgarray($')
      ar
    end
  end

  def _parse_safe_pgarray(text, &block)
    values = []
    return values  if text =~ /^\}\s*/
    if text =~ /^\{\s*/
      text = $'
      while true
        ar, rest = _parse_safe_pgarray(text, &block)
        values << ar
        if rest =~ /^\}\s*/
          return values, $'
        elsif rest =~ /^,\s*/
          rest = $'
        else
          raise "Mailformed postgres array"
        end
        text = rest
      end
    else
      while true
        raise 'Mailformed Array' unless text =~ /^([^,\}]*)([,\}])\s*/
        val, sep, rest = $1, $2, $'
        values << (val == NULL ? nil : yield(val))
        if sep == '}'
          return values, rest
        end
        text = rest
      end
    end
  end

  def parse_pgarray(text, &block)
    raise "Mailformed postgres array" unless text =~ /^\{\s*/
    ar, rest = _parse_pgarray($', &block)
    ar
  end

  def _parse_pgarray(text, &block)
    values = []
    return values  if text =~ /^\}\s*/
    if text =~ /^\{\s*/
      text = $'
      while true
        ar, rest = _parse_pgarray(text, &block)
        values << ar
        if rest =~ /^\}\s*/
          return values, $'
        elsif rest =~ /^,\s*\{\s*/
          rest = $'
        else
          raise "Mailformed postgres array"
        end
        text = rest
      end
    else
      while true
        if text =~ /^"((?:\\.|[^"\\])*)"([,}])\s*/
          val, sep, rest = $1, $2, $'
          val.gsub!(/\\(.)/, '\1')
          val = yield val
        elsif text =~ /^([^,\}]*)([,}])\s*/
          val, sep, rest = $1, $2, $'
          val = val == NULL ? nil : yield(val)
        else
          raise "Mailformed postgres array"
        end
        values << val
        if sep == '}'
          return values, rest
        end
        text = rest
      end
    end
  end

  def _remap_array(array, &block)
    array.map{|v|
      case v
      when Array
        _remap_array(v, &block)
      when nil
        nil
      else
        yield v
      end
    }
  end

  def prepare_pg_integer_array(value)
    val = _remap_array(value){|v| v.to_i}.inspect
    val.gsub!(NIL, NULL)
    val.tr!(SQUARE_BRACKETS, CURLY_BRACKETS)
    val
  end

  def prepare_pg_float_array(value)
    val = _remap_array(value){|v| v.to_f}.inspect
    val.gsub!(NIL, NULL)
    val.tr!(SQUARE_BRACKETS, CURLY_BRACKETS)
    val
  end

  def prepare_pg_safe_array(value)
    value = value.map{|val|
        case val
        when Array
          prepare_pg_safe_array(val)
        when nil
          NULL
        else
          val.to_s
        end
    }.join(',')
    "{#{value}}"
  end

  def prepare_pg_text_array(value)
    value = value.map{|val|
      case val
      when Array
        prepare_pg_text_array(val)
      when nil
        NULL
      else
         "\"#{val.to_s.gsub(/\\|"/){|s| ESCAPE_HASH[s]}}\""
      end
    }.join(',')
    "{#{value}}"
  end

  def _prepare_pg_string_array(value, &block)
    value = value.map{|val|
      case val
      when Array
        _prepare_pg_string_array(val, &block)
      when nil
        NULL
      else
        val = yield val
        if val =~ /^'(.*)'$/m
          "\"#{ $1.gsub(/\\|"/){|s| ESCAPE_HASH[s]} }\""
        else
          val
        end
      end
    }.join(',')
    "{#{value}}"
  end
  alias prepare_pg_string_array _prepare_pg_string_array
end
