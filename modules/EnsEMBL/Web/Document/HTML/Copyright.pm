package EnsEMBL::Web::Document::HTML::Copyright;
use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;

@EnsEMBL::Web::Document::HTML::Copyright::ISA = qw(EnsEMBL::Web::Document::HTML);

sub render {
  my @time = localtime();
  my $year = @time[5] + 1900;
  $_[0]->print( qq(
   <div id="copy"><div id="a1"><div id="a2">
    <p class="center">
    &copy; $year <a href="http://www.sanger.ac.uk/" class="nowrap">WTSI</a> /
    <a href="http://www.ebi.ac.uk/" style="white-space:nowrap">EBI</a>.
    Ensembl is available to <a href="http://www.ensembl.org/info/downloads/index.html">download for public use</a> - please see the <a href="http://www.ensembl.org/info/about/legal/">code licence</a> for details.
    </p>
    </div></div></div>
    ) 
  );
}

1;

