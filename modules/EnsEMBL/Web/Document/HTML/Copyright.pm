# $Id$

package EnsEMBL::Web::Document::HTML::Copyright;

### Copyright notice for footer (basic version with no logos)

use strict;

use base qw(EnsEMBL::Web::Document::HTML);

sub new { return shift->SUPER::new( 'sitename' => '?' ); }

sub sitename :lvalue { $_[0]{'sitename'};   }

sub _content {
  my @time = localtime;
  my $year = @time[5] + 1900;
  
  return qq{
    <div class="twocol-left left unpadded">
      &copy; $year <span class="print_hide"><a href="http://www.sanger.ac.uk/" class="nowrap">WTSI</a> / 
      <a href="http://www.ebi.ac.uk/" style="white-space:nowrap">EBI</a></span> 
      <span class="screen_hide_inline">WTSI / EBI</span>
    </div>
  };
}

sub init {
  $_[0]->sitename = $_[0]->species_defs->ENSEMBL_SITETYPE;
}

1;

