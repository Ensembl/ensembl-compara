=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::eDoc::Writer;

### Output component of the e! doc documentation system. This class
### controls the display of the documentation information collected.

use strict;
use warnings;

sub new {
  my ($class, %params) = @_;
  my $type_order = [qw(constructor accessor miscellaneous undocumented)];
  my $self = {
    'location'    => $params{'location'}    || '',
    'base'        => $params{'base'}        || '',
    'serverroot'  => $params{'serverroot'}  || '',
    'support'     => $params{'support'}     || '',
    'type_order'  => $type_order,
  };
  bless $self, $class;
  return $self;
}

sub location {
  my ($self, $loc) = @_;
  $self->{'location'} = $loc if $loc;
  return $self->{'location'};
}

sub base {
  my ($self, $base) = @_;
  $self->{'base'} = $base if $base;
  return $self->{'base'};
}

sub serverroot {
  my ($self, $root) = @_;
  $self->{'serverroot'} = $root if $root;
  return $self->{'serverroot'};
}

sub support {
  my ($self, $support) = @_;
  $self->{'support'} = $support if $support;
  return $self->{'support'};
}

sub type_order {
  my ($self, $order) = @_;
  $self->{'type_order'} = $order if $order;
  return $self->{'type_order'};
}

sub write_info_page {
  ### Writes information page for the documentation.
  my ($self, $modules) = @_;
  open (my $fh, ">", $self->location . "/info.html") or die "$!: " . $self->location;
  print $fh $self->html_header();
  print $fh '
<div class="front">
  <h1><i><span style="color:#3366bb">e</span><span style="color:#880000">!</span></i> documentation info</h1>
  <div class="coverage">
  <table>
    <tr>
      <th style="width:20%">Family</th>
      <th style="width:40%;text-align:center">Size</th>
      <th style="width:40%;text-align:center">Average coverage</th>
    </tr>';
  my %count;
  my %total;
  my %average;
  foreach my $module (@{ $modules }) {
    my @elements = split /::/, $module->name;
    my $final = pop @elements;
    my $family = "";
    foreach my $element (@elements) {
      $family .= $element . "::";
      if (!$count{$family}) {
        $count{$family} = 0;
      }
      $count{$family}++;
    }
  }
  foreach my $module (@{ $modules }) {
    foreach my $family (keys %count) {
      if (!$total{$family}) {
        $total{$family} = 0;
      }
      if ($module->name =~ /^$family/) {
        $total{$family} += $module->coverage;
      }
    }
  }

  foreach my $family (keys %count) {
    $average{$family} = ($total{$family} / $count{$family});
  }

  foreach my $family (reverse sort { $average{$a} <=> $average{$b} } keys %average) {
    my $text = $family;
    $text =~ s/::$//;

    print $fh '
    <tr>
      <td>', $text, '</td>
      <td style="text-align:center">', $count{$family},'</td>
      <td style="text-align:center">', sprintf("%.0f", $average{$family}), '%</td>
    </tr>';
  }

  print $fh '
  </table>
  <br />
  <br />
  <a href="base.html">&larr; Home</a>
  <br /><br />
  </div>',
  $self->html_footer;
}

sub write_package_frame {
  ### Writes the HTML package listing.
  my ($self, $modules) = @_;
  open (my $fh, ">", $self->location . "/package.html") or die "$!: " . $self->location;
  print $fh $self->html_header( (class => "list" ));
  print $fh qq(<div class="heading">Packages</div>);
  print $fh qq(<p><b>&nbsp;ensembl-webcode</b></p>);
  print $fh qq(<ul>);
  my $previous = '';
  foreach my $module (sort {$a->plugin cmp $b->plugin || $a->name cmp $b->name} @{ $modules }) {
    if ($module->plugin && $module->plugin ne $previous) {
      print $fh qq(</ul>);
      print $fh '<p><b>&nbsp;public-plugins/'.$module->plugin.'</b></p>';
      print $fh qq(<ul>);
    }
    my $module_link = sprintf('<a href="%s" target="base">%s</a>', $self->link_for_module($module), $module->name);
    print $fh "<li>$module_link</li>\n";
    $previous = $module->plugin;
  }
  print $fh qq(</ul>);
  print $fh $self->html_footer;
}

sub write_method_frame {
  ### Writes a complete list of methods from all modules to an HTML file.
  my ($self, $methods) = @_;
  open (my $fh, ">", $self->location . "/methods.html") or die "$!: " . $self->location;
  print $fh $self->html_header( (class => "list" ));
  print $fh qq(<div class="heading">All Methods</div>);
  print $fh qq(<ul>);
  my %exists = ();
  foreach my $method (@{ $methods }) {
    $exists{$method->name}++;
  }
  foreach my $method (sort { $a->name cmp $b->name } @{ $methods }) {
    my $module_suffix = "";
    if ($exists{$method->name} > 1) {
      $module_suffix = " (" . $method->module->name . ")";
    }
    if ($method->name ne "") {
      print $fh "<li>" . $self->link_for_method($method) . $module_suffix . "</li>\n";
    }
  }
  print $fh qq(</ul>);
  print $fh $self->html_footer;
}

sub write_hierarchy {
  ### Returns a formatted list of inheritance and subclass information for a given module.
  my ($self, $module) = @_;
  my $html = "";
  if (@{ $module->inheritance }) {
    $html .= '<div class="hier">';
    $html .= "<h3>Inherits from:</h3>\n";
    $html .= "<ul>\n";
    foreach my $module (@{ $module->inheritance }) {
      $html .= '<li><a href="' . $self->link_for_module($module) . '">' . $module->name . "</a></li>\n";
    }
    $html .= "</ul>\n";
    $html .= "</div>";
  } else {
    $html .= '<div class="hier">No superclasses</div>';
  }

  if ($module->plugin) {
    my $path = $self->base."/".$self->path_from_class($module->name).'.html';
    $html .= '<div class="hier">';
    $html .= "<h3>Extends:</h3>\n";
    $html .= "<ul>\n";
    $html .= '<li>ensembl-webcode: <a href="' . $path . '">' . $module->name . "</a></li>\n";
    $html .= "</ul>\n";
    $html .= "</div>";
  }

  if (@{ $module->subclasses } > 0) {
    $html .= '<div class="hier">';
    $html .= "<h3>Subclasses:</h3>\n";
    $html .= "<ul>\n";
    foreach my $subclass (sort { $a->name cmp $b->name } @{ $module->subclasses }) {
      $html .= '<li><a href="' . $self->link_for_module($subclass) . '">' . $subclass->name. "</a></li>\n";
    }
    $html .= "</ul>\n";
    $html .= "</div>";
  } else {
    $html .= '<div class="hier">No subclasses</div>';
  }

  return $html;
}

sub write_module_page {
  ### Writes the complete HTML documentation page for a module. 
  my ($self, $module, $version) = @_;
  open (my $fh, ">", $self->_html_path_from_module($module));
  my $location = $module->location;
  my $root = $self->serverroot;
  $location =~ s/$root//g;
  my $repo = 'ensembl-webcode';
  my $overview = $module->overview ? $self->markup_documentation($module->overview)
                                    : '<p>No overview present</p>';
  print $fh $self->html_header( (class => $module->name) ),'
  <div class="title">
    <h1>' . $module->name . '</h1>
    Location: ', $location, '<br />
    <a href="', $self->source_code_link($version, $repo, $module) , '" rel="external">View source code on github</a> &middot;
    <a href="', $self->link_for_module($module), '">Permalink</a>
  </div>
  <div class="content">

    <div class="overview">
      <h2>Overview</h2>',
      $overview,
      '<p>Documentation coverage: ', sprintf("%.0f", $module->coverage), ' %</p>
    </div>
    <div class="wrapper">
      <div class="twocol">',
        $self->toc_html($module),'
      </div>
      <div class="twocol">',
        $self->write_hierarchy($module),'
      </div>
    </div>
    <div class="definitions">',
      $self->methods_html($module, $version),'
    </div>

  </div>
  <div class="footer">&larr; 
    <a href="', "../" x element_count_from_class($module->name),'base.html">eDocs home</a> &middot;
    <a href="', $self->source_code_link($version, $repo, $module),'" rel="external">View source code on github</a>
  </div>',
    $self->html_footer;
}

sub source_code_link {
  my ($self, $version, $repo, $module) = @_;
  (my $class = $module->name) =~ s/::/\//g;
  my $branch = $version eq 'master' ? 'master' : "release/$version";
  return sprintf 'https://github.com/Ensembl/%s/blob/%s/modules/%s.pm', $repo, $branch, $module->name;
}

sub write_module_pages {
  ### Writes module documentation page for every found module.
  my ($self, $modules, $version) = @_;
  foreach my $module (@{ $modules }) {
    $self->write_module_page($module, $version);
  }
}

sub toc_html {
  ### Returns the table of contents for the module methods.
  my ($self, $module) = @_;
  my $html = "";

  $html .= '<h2>Methods by Type</h2>';
  foreach my $section (@{ $self->type_order }) {
    next unless scalar(@{ $module->methods_for_section($section) });
    $html .= "<h3>" . ucfirst($section) . "</h3>\n";
    $html .= "<ul>";
    foreach my $method (sort {$a->name cmp $b->name} @{ $module->methods_for_section($section) }) {
      if ($method->section !~ /undocumented/) {
        $html .= '<li><a href="#' . $method->name . '">' . $method->name . '</a>';
        if ($method->module->name ne $module->name) {
          $html .= " (" . $method->module->name . ")";
        }
        $html .= "</li>\n";
      } else {
        $html .= "<li>" . $method->name;

        if ($method->module->name ne $module->name) {
          $html .= " (" . $method->module->name . ")";
        }

        $html .= "</li>\n";
      }
    }
    $html .= "</ul>";
  }
  return $html;
}

sub markup_documentation {
  ### Marks up documentation text for links and embedded tables. See also {{markup_links}} and {{markup_embedded_table}}.
  my ($self, $overview) = @_;
  my $html = "";
  my @contents = split(/___/, $overview);
  my $count = 0;
  foreach my $content (@contents) {
    $count++;
    if ($count == 1) {
      $html .= $content;
    }
    if ($count == 2) {
      #$html .= $self->markup_embedded_table($content);
    }
    if ($count == 3) {
      $html .= $content;
      $count = 0;
    }
  }
  return $self->markup_links($html);
}

sub methods_html {
  ### Returns a formatted list of method names and documentation.
  my ($self, $module, $version) = @_;
  my $html = "";
  $html .= qq(<h2>Method Documentation</h2>);
  $html .= qq(<dl>);
  my $count = 0;
  foreach my $method (@{ $module->methods }) {
    if ($method->section !~ /undocumented/) {
      my $complete = $module->name . "::" . $method->name;
      $count++;
      $html .= qq(<dt><a id=") . $method->name . qq("></a>) . $method->name . qq(</dt>\n<dd>);
      if (scalar(@{$method->type||[]})) {
        $html .= '<b>Type</b>: '.join(' ', @{$method->type}).'<br />';
      }
      $html .= $self->markup_documentation($method->documentation);
      if ($method->result) {
        $html .= qq(<i>) . $self->markup_links($method->result) . qq(</i>\n);
      }
      if ($method->module->name ne $module->name) {
        $complete = $method->module->name . "::" . $method->name;
        $html .= qq(Inherited from <a href=") . $self->link_for_module($method->module) . qq(">) . $method->module->name . "</a>";
      }
      $html .= '</dd>';
      #$html .= sprintf '<a href="%s" rel="external">View source on github</a>', $self->source_code_link($version, 'ensembl-webcode', $complete);
     # $html .= "<div id='" . $complete . "' style='display: none;'>" . $complete . "</div>";
    }
  }
  if (!$count) {
    $html .= qq(No documented methods.);
  }
  $html .= qq(</dl>);
  return $html;
}

sub markup_links {
  ### Parses documentation for special e! doc markup. Links to other modules and methods can be included between double braces. For example: { { EnsEMBL::Web::Tools::Document::Module::new } } is parsed to {{EnsEMBL::Web::Tools::Document::Module::new}}. Simple method and module names can also be used. {{markup_links}} does not perform any error checking on the names of modules and methods. 
  my ($self, $documentation) = @_;
  my $markup = $documentation;
  $_ = $documentation;
  while (/{{(.*?)}}/g) {
    my $name = $1;
    if ($name =~ /\:\:/) {
      my @elements = split /\:\:/, $name;
      if ($elements[$#elements] =~ /^[a-z]/) {
        my $class = "";
        my $path = "";
        my $method = $elements[$#elements];
        for (my $n = 0; $n < $#elements; $n++) {
          $class .= $elements[$n] . "::";
        }
        $class =~ s/\:\:$//;
        my $link = "<a href='" . $self->link_for_class($class) . "#$method'>" . $class . "::" . $method . "</a>";
        $markup =~ s/{{$name}}/$link/;
      } else {
        my $link = "<a href='" . $self->link_for_class($name) . "'>" . $name . "</a>";
        $markup =~ s/{{$name}}/$link/;
      }
    } else {
      my $link = "<a href='#$name'>$name</a>";
      $markup =~ s/{{$name}}/$link/;
    }
  }
  return $markup;
}

sub write_base_frame {
  ### Writes the home page for the e! doc.
  my ($self, $modules) = @_;
  open (my $fh, ">", $self->location . "/base.html");
  my $total = 0;
  my $count = 0;
  my $overview_total = 0;
  my $methods = 0;
  my $lines = 0;
  foreach my $module (@{ $modules }) {
    $count++;
    $total += $module->coverage;
    $overview_total++ if $module->overview;
    $methods += @{ $module->methods };
    $lines += $module->lines;
  }
  my $coverage = 0;
  my $overview_coverage = 0;
  if ($count == 0) {
    warn "No modules indexed!";
  } else {
    $coverage = $total / $count;
    $overview_coverage = $overview_total / $count * 100;
  }
  print $fh $self->html_header;
  print $fh "<div class='front'>";
  print $fh "<h1><i><span style='color: #3366bb'>e</span><span style='color: #880000'>!</span></i> web code documentation</h1>";
  print $fh qq(<div class='coverage'>);
  print $fh qq(Overview coverage: ) . sprintf("%.0f", $overview_coverage) . qq( %<br />);
  print $fh qq(Method coverage: ) . sprintf("%.0f", $coverage) . qq( %);
  print $fh qq(</div>);
  print $fh "<div class='date'>" . $count . " modules<br />\n";
  print $fh "" . $methods . " methods<br />\n";
  print $fh "" . $lines . " lines of source code<br /><br />\n";
  print $fh "<a href='info.html'>More info &rarr;</a><br />\n";
  print $fh "</div>";
  print $fh "<div class='date'>Last built: " . localtime() . "</div>";
  print $fh "</div>";
  print $fh $self->html_footer;
}

sub write_frameset {
  ### Writes the frameset for the e! doc collection.
  my $self = shift;

  open FH, '>', $self->location . '/iframe.html';
  print FH '
    <!--#set var="decor" value="none"-->
    <html>
    <head>
      <title>e! doc</title>
    </head>
    <frameset rows="25%, 75%">
    <frameset cols="50%,50%">
        <frame src="package.html" title="e! doc" name="packages">
        <frame src="methods.html"  name="methods">
    </frameset>
    <frame src="base.html" name="base">
    <noframes>
          <body bgcolor="white">
            You need frames to view the e! documentation.
          </body>
    </noframes>
    </frameset>
    </html>
  ';

  close FH;

  open FH, '>', $self->location . '/index.html';
  print FH '
    <html>
    <head>
      <title>e! doc</title>
    </head>
    <body>
    <div id="static">
      <iframe src="iframe.html" id="pdoc_iframe" width="100%" height="1000px"></iframe>
    </div>
    </body>
    </html>
  ';

  close FH;
}

sub link_for_method {
  ### Returns the HTML formatted link to a method page in a module page.
  my ($self, $method) = @_;
  return sprintf '<a href="%s#%s" target="base">%s</a>', 
                  $self->link_for_module($method->module), 
                  $method->name, $method->name;
}

sub copy_support_files {
  ### Copies support files (stylesheets etc) to the export location (set by {{support}}.
  my $self = shift;
  return;
  my $source = $self->support;
  my $destination = $self->location;
  if ($source) {
    my $cp = `cp $source/* $destination/`;
  }
}

sub html_header {
  ### Returns an HTML header. 
  my ($self, %params) = @_;
  my $class = $params{class};
  my $title = $params{title} ? $params{title} : "e! doc";
  if ($class) {
    $class = " class='" . $class . "'";
  } else {
    $class = "";
  }
  my $html = "";
  $html = qq(<!--#set var="decor" value="none"-->
<html>
  <head>
    <title>e! doc</title>
    <link href="/edoc.css" rel="stylesheet" type="text/css" media="all" />
  </head>
  <body $class>);
  return $html;
}

sub include_stylesheet {
  ### Returns the HTML to include a CSS stylesheet.
  return;
}

sub include_javascript {
  ### Returns HTML to include a javascript file.
  return;
}

sub package_prefix {
  ### Returns the relative path prefix for a particular 
  ### package name.
  my ($self, $class) = @_;
  my $html = "";
  if (element_count_from_class($class)) {
     $html .= ("../" x element_count_from_class($class));
  }
  return $html;
}

sub html_footer {
  ### Returns a simple HTML footer
  return qq(
    </body>
    </html>
  );
}

sub _html_path_from_module {
  ### Returns an export location from a package
  my ($self, $module) = @_;
  my $path = $self->location . "/";
  $path .= $self->path_from_module($module) . ".html";
  return $path;
}

sub link_for_module {
  ### Returns the HTML location of a module, excluding &lt;A HREF&gt; markup.
  my ($self, $module) = @_;
  my $path = $self->base . "/";
  $path .= $self->path_from_module($module) . ".html";
  return $path;
}

sub link_for_class {
  ### Returns the HTML location of a base class, excluding &lt;A HREF&gt; markup.
  ### Only needed by link markup, which lacks a module object
  my ($self, $class) = @_;
  my $path = $self->base . "/";
  $path .= $self->path_from_class($class) . ".html";
  return $path;
}

sub path_from_module {
  ### Creates directory into which file can be written
  ### and returns URL path to module
  my ($self, $module) = @_;
  my $class = $module->name;
  my @elements = split(/::/, $class);
  my $file = pop @elements;
  unshift @elements, $module->plugin if $module->plugin;

  ## Create file path
  my $path = $self->location;
  foreach my $element (@elements) {
    $path = $path . "/" . $element;
    if (!-e $path) {
      print "Creating $path\n";
      my $mk = `mkdir $path`;
    }
  }

  ## Return file URL
  my $url = '';
  $url .= join('/', @elements);
  $url .= '/'.$file;
  return $url;
}

sub path_from_class {
  ### returns URL path to module
  my ($self, $class) = @_;
  $class =~ s/::/\//g;
  return $class;
}

sub element_count_from_class {
  ### Returns the number of elements in a package name.
  my $class = shift;
  if ($class) {
    my @elements = split(/::/, $class);
    return $#elements;
  }
  return 0;
}


1;
