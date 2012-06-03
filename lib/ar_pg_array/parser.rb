require 'json'

module PgArrayParser
  CURLY_BRACKETS = '{}'.freeze
  SQUARE_BRACKETS = '[]'.freeze
  NULL = 'NULL'.freeze
  NIL = 'nil'.freeze

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
        elsif rest =~ /^,\s*{\s*/
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
end
