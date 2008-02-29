package EnsEMBL::Web::Document::HTML::SearchBox;
use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;
use EnsEMBL::Web::RegObj;
                                                                                
our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub new    { return shift->SUPER::new( 'links' => [], 'indexes' => [] ); }

sub add_link  {
  my $species = $ENV{'ENSEMBL_SPECIES'} || $ENV{'ENSEMBL_PRIMARY_SPECIES'}; 
  push @{$_[0]->{'links'}}, sprintf( '<a href="/%s/%s">%s</a>', $species, CGI::escapeHTML( $_[1] ), CGI::escapeHTML( $_[2] ) ); 
}
sub add_index { push @{$_[0]->{'indexes'}}, $_[1]; }

sub sp_common  :lvalue { $_[0]{'sp_common'}=~s/_/ /g; $_[0]{'sp_common'}; }

sub render {
  my $self   = shift;
  my $species = $ENV{'ENSEMBL_SPECIES'};
  if( $species eq 'Multi' ) { $species = ''; }
  my $common = $species ? $self->sp_common : '';
  my $site_section;
  my $ebang = qq(<i><span style="color:#3366bb">e</span><span class="red">!</span></i>);
  if( $common ) {
    if( $common =~ /\./ ) { # looks like a Latin name
      $site_section = "$ebang <i>$common</i>"; 
    } else {
      $site_section = "$ebang $common";
    }
  } else {
    $site_section = 'Ensembl';
  }
  my $script = 'psychic';# $SD->ENSEMBL_SEARCH;
  $self->print( qq(
<div id="search">
<form action="/@{[$species||'perl']}/psychic" method="get" id="seform">
  <input type="hidden" id="species" name="species" value="$species" />
  <input type="hidden" id="se_si" name="site" value="ensembl" />
  <table id="se">
    <tr>
      <td id="se_but"><img title="Ensembl search" id="se_im" src="/img/small-ensembl.gif" alt="Ensembl search" /><img src="/img/small-down.gif" style="width:7px" alt=":" /></td>
      <td><input id="se_q" type="text" name="query" /></td>
      <td style="cursor: hand; cursor: pointer;"><input type="submit"  style="cursor: hand; cursor: pointer;margin:0px; border:0px;background-color:#fff;padding:1px 0.5em;font-weight: bold;" value="Search&gt;&gt;" /></td>
    </tr>
  </table>
  <dl style="display: none" id="se_mn"></dl>
</form>));
  if( @{$self->{'links'}} ) {
    $self->print( qq(\n  <p class="right" style="clear:right; margin-right:1em">e.g. ), join( ", ", @{$self->{'links'}} ), '</p>' );
  }
  $self->print( qq(
</div>));
}

1;

