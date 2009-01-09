package EnsEMBL::Web::Document::HTML::Copyright;

### Copyright notice for footer (basic version with no logos)

use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub new { return shift->SUPER::new( 'sitename' => '?' ); }

sub sitename    :lvalue { $_[0]{'sitename'};   }


sub render {
  my @time = localtime();
  my $year = @time[5] + 1900;

  $_[0]->print( qq(
  <div class="twocol-left left unpadded">
     &copy; $year <span class="print_hide"><a href="http://www.sanger.ac.uk/" class="nowrap">WTSI</a> /
      <a href="http://www.ebi.ac.uk/" style="white-space:nowrap">EBI</a></span>
      <span class="screen_hide_inline">WTSI / EBI</span>
  </div>) 
  );
}

1;

