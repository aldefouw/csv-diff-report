require 'cgi'


class CSVDiff

    # Defines functionality for exporting a Diff report in HTML format.
    module Html

        private

        # Generare a diff report in HTML format.
        def html_output(output)
            content = []
            content << '<html>'
            content << '<head>'
            content << '<title>Diff Report</title>'
            content << '<meta http-equiv="Content-Type" content="text/html; charset=utf-8">'
            content << html_styles
            content << '</head>'
            content << '<body>'

            html_summary(content)
            @diffs.each do |file_diff|
                html_diff(content, file_diff) if file_diff.diffs.size > 0
            end

            content << '</body>'
            content << '</html>'

            # Save page
            path = "#{File.dirname(output)}/#{File.basename(output, File.extname(output))}.html"
            File.open(path, 'w'){ |f| f.write(content.join("\n")) }
            path
        end

        # Returns the HTML head content, which contains the styles used for diffing.
        def html_styles
            style = <<-EOT
                <style>
                    @font-face {font-family: Calibri;}

                    h1 {font-family: Calibri; font-size: 16pt;}
                    h2 {font-family: Calibri; font-size: 14pt; margin: 1em 0em .2em;}
                    h3 {font-family: Calibri; font-size: 12pt; margin: 1em 0em .2em;}
                    body {font-family: Calibri; font-size: 11pt;}
                    p {margin: .2em 0em;}
                    table {font-family: Calibri; font-size: 10pt; line-height: 12pt; border-collapse: collapse;}
                    th {background-color: #00205B; color: white; font-size: 11pt; font-weight: bold; text-align: left;
                        border: 1px solid #DDDDFF; padding: 1px 5px;}
                    td {border: 1px solid #DDDDFF; padding: 1px 5px;}

                    .summary {font-size: 13pt;}
                    .add {background-color: white; color: #33A000;}
                    .delete {background-color: white; color: #FF0000; text-decoration: line-through;}
                    .update {background-color: white; color: #0000A0;}
                    .move {background-color: white; color: #0000A0;}
                    .matched {background-color: white; color: #A0A0A0;}
                    .bold {font-weight: bold;}
                    .center {text-align: center;}
                    .right {text-align: right;}
                    .separator {width: 200px; border-bottom: 1px gray solid;}
                </style>
            EOT
            style
        end


        def html_summary(body)
            body << '<h2>Summary</h2>'

            body << '<p>Source Locations:</p>'
            body << '<table>'
            body << '<tbody>'
            body << "<tr><th>From:</th><td>#{@left}</td></tr>"
            body << "<tr><th>To:</th><td>#{@right}</td></tr>"
            body << '</tbody>'
            body << '</table>'
            body << '<br>'
            body << '<p>Files:</p>'
            body << '<table>'
            body << '<thead>'
            body << "<tr><th rowspan=2>File</th><th colspan=2 class='center'>Lines</th><th colspan=4 class='center'>Diffs</th></tr>"
            body << "<tr><th>From</th><th>To</th><th>Adds</th><th>Deletes</th><th>Updates</th><th>Moves</th></tr>"
            body << '</thead>'
            body << '<tbody>'
            @diffs.each do |file_diff|
                label = File.basename(file_diff.left.path)
                body << '<tr>'
                if file_diff.diffs.size > 0
                    body << "<td><a href='##{label}'>#{label}</a></td>"
                else
                    body << "<td>#{label}</td>"
                end
                body << "<td class='right'>#{file_diff.left.line_count}</td>"
                body << "<td class='right'>#{file_diff.right.line_count}</td>"
                body << "<td class='right'>#{file_diff.summary['Add']}</td>"
                body << "<td class='right'>#{file_diff.summary['Delete']}</td>"
                body << "<td class='right'>#{file_diff.summary['Update']}</td>"
                body << "<td class='right'>#{file_diff.summary['Move']}</td>"
                body << '</tr>'
            end
            body << '</tbody>'
            body << '</table>'
        end


        def html_diff(body, file_diff)
            label = File.basename(file_diff.left.path)
            body << "<h2 id=#{label}>#{label}</h2>"
            body << '<p>'
            count = 0
            if file_diff.summary['Add'] > 0
                body << "<span class='add'>#{file_diff.summary['Add']} Adds</span>"
                count += 1
            end
            if file_diff.summary['Delete'] > 0
                body << ', ' if count > 0
                body << "<span class='delete'>#{file_diff.summary['Delete']} Deletes</span>"
                count += 1
            end
            if file_diff.summary['Update'] > 0
                body << ', ' if count > 0
                body << "<span class='update'>#{file_diff.summary['Update']} Updates</span>"
                count += 1
            end
            if file_diff.summary['Move'] > 0
                body << ', ' if count > 0
                body << "<span class='move'>#{file_diff.summary['Move']} Moves</span>"
            end
            body << '</p>'

            out_fields = output_fields(file_diff)
            cols_with_value = columns_with_changes_detected(file_diff, out_fields)

            body << '<table>'
            body << '<thead><tr>'
            out_fields.each do |fld|
                body << "<th>#{fld.is_a?(Symbol) ? titleize(fld) : fld}</th>" if include_column?(cols_with_value, file_diff, fld)
            end
            body << '</tr></thead>'
            body << '<tbody>'
            file_diff.diffs.sort_by{|k, v| v[:row] }.each do |key, diff|
                body << '<tr>'
                chg = diff[:action]
                out_fields.each_with_index do |field, i|
                    old, new = nil, nil
                    style = case chg
                    when 'Add', 'Delete' then chg.downcase
                    end
                    d = diff[field]
                    if d.is_a?(Array)
                        old = d.first
                        new = d.last
                        if old.nil?
                            style = 'add'
                        else
                            style = chg.downcase
                        end
                    elsif d
                        new = d
                        style = chg.downcase if i == 1
                    elsif file_diff.options[:include_matched]
                        style = 'matched'
                        d = file_diff.right[key] && file_diff.right[key][field]
                    end
                    if include_column?(cols_with_value, file_diff, field)
                        body << '<td>'
                        body << "<span class='delete'>#{CGI.escapeHTML(old.to_s)}</span>" if old
                        body << '<br>' if old && old.to_s.length > 10
                        body << "<span#{style ? " class='#{style}'" : ''}>#{CGI.escapeHTML(new.to_s)}</span>"
                        body << '</td>'
                    end
                end
                body << '</tr>'
            end
            body << '</tbody>'
            body << '</table>'
        end

        def columns_with_changes_detected(file_diff, out_fields)
            cols_with_value = []
            file_diff.diffs.each { |key, diff| out_fields.each { |f| cols_with_value << f if value_mismatch?(diff, f) } }
            cols_with_value.uniq!
        end

        def value_mismatch?(diff, f)
            diff[f].is_a?(Array) && diff[f][1].to_s.strip != diff[f][0].to_s.strip
        end

        def include_column?(cols_with_value, file_diff, field)
            (!cols_with_value.nil? && cols_with_value.include?(field)) ||
            file_diff.key_fields.include?(field) ||
            field == :row ||
            field == :action ||
            field == :sibling_position
        end
    end

end
