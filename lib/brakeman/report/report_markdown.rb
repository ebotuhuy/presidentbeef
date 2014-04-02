Brakeman.load_brakeman_dependency 'terminal-table'



class Brakeman::Report::Markdown < Brakeman::Report::Base

  class MarkdownTable < Terminal::Table

    def initialize options = {}, &block
      options[:style] ||= {}
      options[:style].merge!({
          :border_x => '-',
          :border_y => '|',
          :border_i => '|'
      })
      super options, &block
    end

    def render
      super.split("\n")[1...-1].join("\n")
    end
    alias :to_s :render

  end

  def generate_report
    out = text_header <<
    "### SUMMARY\n\n" <<
    generate_overview.to_s         << "\n\n" <<
    generate_warning_overview.to_s << "\n\n"

    #Return output early if only summarizing
    return out if tracker.options[:summary_only]

    if tracker.options[:report_routes] or tracker.options[:debug]
      out << "### CONTROLLERS"  << "\n\n" <<
      generate_controllers.to_s << "\n\n"
    end

    if tracker.options[:debug]
      out << "### TEMPLATES\n\n" <<
      generate_templates.to_s << "\n\n"
    end

    res = generate_errors
    out << "### Errors\n\n" << (res.to_s << "\n\n") if res

    res = generate_warnings
    out << "### SECURITY WARNINGS\n\n" << (res.to_s << "\n\n") if res

    res = generate_controller_warnings
    out << "### Controller Warnings:\n\n" << (res.to_s << "\n\n") if res

    res = generate_model_warnings
    out << "### Model Warnings:\n\n" << (res.to_s << "\n\n") if res

    res = generate_template_warnings
    out << "### View Warnings:\n\n" << (res.to_s << "\n\n") if res

    out
  end

  def generate_overview
    num_warnings = all_warnings.length

    MarkdownTable.new(:headings => ['Scanned/Reported', 'Total']) do |t|
      t.add_row ['Controllers', tracker.controllers.length]
      t.add_row ['Models', tracker.models.length - 1]
      t.add_row ['Templates', number_of_templates(@tracker)]
      t.add_row ['Errors', tracker.errors.length]
      t.add_row ['Security Warnings', "#{num_warnings} (#{warnings_summary[:high_confidence]})"]
      t.add_row ['Ignored Warnings', ignored_warnings.length] unless ignored_warnings.empty?
    end
  end

  #Generate listings of templates and their output
  def generate_templates
    out_processor = Brakeman::OutputProcessor.new
    template_rows = {}
    tracker.templates.each do |name, template|
      unless template[:outputs].empty?
        template[:outputs].each do |out|
          out = out_processor.format out
          template_rows[name] ||= []
          template_rows[name] << out.gsub("\n", ";").gsub(/\s+/, " ")
        end
      end
    end

    template_rows = template_rows.sort_by{|name, value| name.to_s}

    output = ''
    template_rows.each do |template|
      output << template.first.to_s << "\n\n"
      table = MarkdownTable.new(:headings => ['Output']) do |t|
        # template[1] is an array of calls
        template[1].each do |v|
          t.add_row [v]
        end
      end

      output << table.to_s << "\n\n"
    end

    output
  end

  def render_array template, headings, value_array, locals
    return if value_array.empty?

    MarkdownTable.new(:headings => headings) do |t|
      value_array.each { |value_row| t.add_row value_row }
    end
  end

  #Generate header for text output
  def text_header
    <<-HEADER

## BRAKEMAN REPORT

**Application path:** #{File.expand_path tracker.options[:app_path]}
**Rails version:** #{rails_version}
**Brakeman version:** #{Brakeman::Version}
**Started at:** #{tracker.start_time}
**Duration:** #{tracker.duration} seconds
**Checks run:** #{checks.checks_run.sort.join(", ")}
HEADER
  end
end
