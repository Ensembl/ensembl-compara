=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Controller::SSI;

use strict;
use warnings;

use Text::MultiMarkdown qw(markdown);

use EnsEMBL::Web::Document::HTML::Movie;
use EnsEMBL::Web::Utils::FileHandler qw(file_get_contents);
use EnsEMBL::Web::Utils::Publications qw(parse_publication_list);

use parent qw(EnsEMBL::Web::Controller);

sub parse_path_segments {} ## @override - don't need type, action, function etc for .html pages

sub page_type       { return 'Static';   }
sub renderer_type   { return 'Apache';   }
sub cacheable       { return 1;          }
sub request         { return 'ssi';      }

sub init {
  my $self  = shift;
  my $page  = $self->page('HTML');
  my $uri   = $self->r->unparsed_uri;

  # all requests coming into this controller are served as html
  $self->r->content_type('text/html; charset=utf-8');

  $page->include_navigation($uri =~ /Doxygen\/index.html/ || ($uri =~ /^\/info/ && $uri !~ /Doxygen\/(\w|-)+/));
  $page->initialize;
  $self->add_JSCSS($page);
  $self->render_page;
}

sub content {
  ## Gets the actual content of the files after replacing the placeholders with relevant substitutions
  my $self = shift;

  if (!$self->{'content'}) {

    # Read html file
    $self->{'content'} = file_get_contents($self->filename);

    # Parse out SSI directives
    $self->{'content'} =~ s/\[\[([A-Z]+)::([^\]]*)\]\]/my $m = "template_$1"; $self->$m($2) || '';/ge;
  }

  return $self->{'content'};
}

sub set_cache_params {
  my $self = shift;
  
  $self->{'url_tag'} = $ENV{'REQUEST_URI'};
  delete $self->{'session_id'};
  
  $self->SUPER::set_cache_params;
}

sub template_SPECIESINFO {
  my ($self, $code) = @_;
  return $self->species_defs->get_config(split /:/, $code);
}

sub template_SPECIESDEFS {
  my ($self, $code) = @_;
  return $self->species_defs->$code;
}

sub template_SPECIES {
  my ($self, $code) = @_;
  return $self->hub->species if $code eq 'code';
  return $self->species_defs->SPECIES_DISPLAY_NAME if $code eq 'name';
  return $self->species_defs->SPECIES_RELEASE_VERSION if $code eq 'version';
  return "**$code**";
}

sub template_RELEASE {
  return shift->species_defs->ENSEMBL_VERSION;
}

sub template_INCLUDE {
  my ($self, $include, $no_error) = @_;
  my $hub = $self && $self->can('hub') ? $self->hub : undef;
  my $static_server;

  if ($hub) {
    $static_server = $self->static_server;
    $static_server = '' if $static_server eq $hub->species_defs->ENSEMBL_BASE_URL; # must use $hub->species_defs rather than $self->species_defs because this function is called directly by Components
  }

  my $content;
  
  $include =~ s/\{\{([A-Z]+)::([^\}]+)\}\}/my $m = "template_$1"; $self->$m($2);/ge;
  
  foreach my $root (@SiteDefs::ENSEMBL_HTDOCS_DIRS) {
    my $filename = "$root/$include";
    
    if (-f $filename && -e $filename) { 
      if (open FH, $filename) {
        local($/) = undef;
        $content = <FH>;
        close FH;

        ## convert markdown into HTML
        if ($filename =~ /\.md$/) {
          $content = markdown($content);
          ## remove escape character on tilde and apostrophe
          $content =~ s/\\~/~/g;
          $content =~ s/\\'/'/g;
          ## replace escape character with line break
          $content =~ s/\\/<br>/g;
          ## Convert PMC IDs to full references
          if ($filename =~ /references/l) {
            $content = parse_publication_list($content, $hub);
          }
        }
        
        $content =~ s/src="(\/i(mg)?\/)/src="$static_server$1/g if $static_server;
        return $content;
      }
    }
  }
  
  # using $hub->apache_handle instead of $self->r because this function is also called by Component modules, providing THEIR $self as this $self
  $hub->apache_handle->log->error('Cannot include virtual file: does not exist or permission denied ', $include) if ($hub && !$no_error);
  
  return $content;
}

sub template_SCRIPT {
  my $self     = shift;
  my $include  = shift;
  my $function = shift || 'render';
  my @args     = ();
  
  # example: [[SCRIPT::EnsEMBL::Web::Document::HTML::Compara::format_wga_list(EPO)]]
  if ($include =~ /^(.*)::([^:]*)\((.*)\)$/) {
    $include  = $1;
    $function = $2;
    push @args, split(q{,}, $3);
  }

  my ($module, $error) = $self->_use($include, $self->hub);
  
  if ($error) {
    warn "Cannot dynamic_use $include: $error";
  } elsif ($module) {
    return $module->$function(@args);  # Object oriented module
  } else {
    return $include->$function(@args); # Non object oriented script
  }
}

sub template_COMPONENT {
  return shift->template_SCRIPT(@_, 'content');
}

sub template_PAGE {
  my ($self, $rel) = @_;
  return $self->species_defs->ENSEMBL_BASE_URL . "/$rel";
}

sub template_LINK {
  my $self = shift;
  my $url  = $self->template_PAGE(@_);
  return qq{<a href="$url">$url</a>}; 
}

sub template_MOVIE {
  my ($self, $movie_params) = @_;
  return EnsEMBL::Web::Document::HTML::Movie->new($self->hub)->render($movie_params) || '<p><i>Movie not found</i></p>';
}

sub template_PERL {
  my ($self, $code) = @_;

  my $string = '';

  {
    local $_  = $self->hub;
    $string   = eval($code);
    warn $@ if $@;
  }

  return $string;
}

sub add_JSCSS {
  my ($self, $page) = @_;

  my $head        = $self->content =~ /<head>(.*?)<\/head>/sm ? $1 : '';
  my $stylesheets = $page->elements->{'stylesheet'};
  my $javascript  = $page->elements->{'javascript'};

  while ($head =~ s/<style(.*?)>(.*?)<\/style>//sm) {
    my ($attr, $cont) = ($1, $2);

    next unless $attr =~ /text\/css/;

    my $media = $attr =~ /media="(.*?)"/ ? $1 : 'all';

    if ($attr =~ /src="(.*?)"/) {
      $stylesheets->add_sheet($1);
    } else {
      $stylesheets->add_sheet($cont);
    }
  }

  while ($head =~ s/<script(.*?)>(.*?)<\/script>//sm) {
    my ($attr, $cont) = ($1, $2);

    next unless $attr =~ /text\/javascript/;

    if ($attr =~ /src="(.*?)"/) {
      $javascript->add_source($1);
    } else {
      $javascript->add_script($cont);
    }
  }

  while ($head =~ s/<link (.*?)\s*\/>//sm) {
    my %attrs = map { s/"//g; split '=' } split ' ', $1;
    next unless $attrs{'rel'} eq 'stylesheet';
    $stylesheets->add_sheet($attrs{'href'}) if $attrs{'href'};
  }
}

1;
