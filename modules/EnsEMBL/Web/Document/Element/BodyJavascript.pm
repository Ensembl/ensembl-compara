=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

# $Id$

package EnsEMBL::Web::Document::Element::BodyJavascript;

use strict;

use base qw(EnsEMBL::Web::Document::Element);

sub new {
  my $self = shift->SUPER::new({
    %{$_[0]},
    scripts => '',
    sources => {},
  });
  
  return $self;
}

sub debug      { return $_[0]{'debug'} ||= $_[0]->hub->param('debug') eq 'js'; }
sub content    { return $_[0]{'scripts'}; }
sub add_script { $_[0]{'scripts'} .= qq{  <script type="text/javascript">\n$_[1]</script>\n} if $_[1]; }

sub init {
  my $self = shift;
  $self->add_sources('components', 'ENSEMBL_JS_NAME', sub { $_[0] =~ /^\d/ && -f "$_[1]/$_[0]"; });
}

sub add_sources {
  my ($self, $dir, $file, $filter) = @_;
  my $species_defs = $self->species_defs;
  
  if ($self->debug) {
    $self->add_dir($_, $dir, $filter) for reverse @{$species_defs->ENSEMBL_HTDOCS_DIRS};
  } else {
    $self->add_source(sprintf '/%s/%s.js', $species_defs->ENSEMBL_JSCSS_TYPE, $species_defs->$file);
  }
}

sub add_dir {
  my ($self, $root, $subdir, $filter) = @_; 
  my $dir      = "$root/$subdir";
     $filter ||= sub { $_[0] =~ /\w/; };
  
  if (-e $dir && -d $dir) {
    opendir DH, $dir;
    my @files = readdir DH; 
    closedir DH;
    
    foreach (sort { -d "$dir/$a" <=> -d "$dir/$b" || lc $a cmp lc $b } grep &$filter($_, $dir), @files) {
      if (-d "$dir/$_") {
        $self->add_dir($root, "$subdir/$_");
      } elsif (-f "$dir/$_" && /\.js$/) {
        $self->add_source("/$subdir/$_");
      }   
    }   
  }
}

sub add_source { 
  my ($self, $src) = @_;
  
  return unless $src;
  return if $self->{'sources'}{$src};
  
  $self->{'sources'}{$src} = 1;
  $self->{'scripts'} .= sprintf qq{  <script type="text/javascript" src="%s%s"></script>\n}, $self->static_server, $src;
}

1;
