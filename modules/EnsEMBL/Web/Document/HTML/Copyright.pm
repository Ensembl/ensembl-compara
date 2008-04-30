package EnsEMBL::Web::Document::HTML::Copyright;
use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;
use EnsEMBL::Web::RegObj;

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub render {
  my @time = localtime();
  my $year = @time[5] + 1900;

  $_[0]->print( qq(
    <div class="twocol-left left unpadded">
    &copy; $year <a href="http://www.sanger.ac.uk/" class="nowrap">WTSI</a> /
    <a href="http://www.ebi.ac.uk/" style="white-space:nowrap">EBI</a>.
    </div>
    ) 
  );
}

1;

