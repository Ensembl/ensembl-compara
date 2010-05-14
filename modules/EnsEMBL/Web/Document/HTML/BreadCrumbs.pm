package EnsEMBL::Web::Document::HTML::BreadCrumbs;

use strict;

use base qw(EnsEMBL::Web::Document::HTML);

# Package to generate breadcrumb links (currently incorporated into masthead)
# Limited to three levels in order to keep masthead neat :)

sub new {
  my $class = shift;
  my $self = $class->SUPER::new('title' => undef );
  return $self;
}

sub title {
  my $self = shift;
  $self->{'title'} = shift if @_;
  return $self->{'title'};
}

sub render   {
  my $self = shift;
  my $species_defs = $self->species_defs;
  my $you_are_here = $ENV{'SCRIPT_NAME'};
  my $html = '<span class="print_hide">';
  my $species = $ENV{'ENSEMBL_SPECIES'};
  my $species_path = $species_defs->species_path;

  # Link to home page
  if ($you_are_here eq '/index.html') {
    $html .= '<strong>Home</strong>';
  } else {
    $html .= '<a href="/">Home</a>';
  }
  
  $html .= '</span>';

  if ($species && $species !~ /multi/i) {
    $html .= '<span class="print_hide"> &gt; </span>';
    if ($species eq 'common') {
      $html .= '<strong>Control Panel</strong>';
    } else {
      $html .= '<a href="/' . $species_defs->GROUP_URL . '/">' . $species_defs->DISPLAY_NAME . '</a> &gt; ' if $species_defs->SPP_ARE_GROUPED;
      
      my $species_name = $species_defs->get_config($species, 'SPECIES_COMMON_NAME');
      $species_name = '<i>' . $species_name . '</i>' if $species_name =~ /\./;
      
      if ($ENV{'ENSEMBL_TYPE'} eq 'Info') {
        $html .= "<strong>$species_name</strong>";
      } else {
        $html .= qq{<a href="$species_path/Info/Index">$species_name</a>};
      }
      
      $html .= ' <span style="font-size:75%">[' . $species_defs->ASSEMBLY_DISPLAY_NAME . ']</span>' if $species_defs->ASSEMBLY_DISPLAY_NAME;
    }
  } elsif ($you_are_here =~ m#^/info/#) {
    $html .= '<span class="print_hide"> &gt; </span>';
    
    # Level 2 link
    if ($you_are_here eq '/info/' || $you_are_here eq '/info/index.html') {
      $html .= '<strong>Docs &amp; FAQs</strong>';
    } else {
      $html .= '<strong><a href="/info/">Docs &amp; FAQs</a></strong>';
    }
    
    $html .= '<span class="print_hide"> &gt; </span>' . $self->title if $self->title;
  }
  
  $self->printf($html);
}

1;

