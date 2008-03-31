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
    <a href="http://www.sanger.ac.uk"><img src="/img/wtsi_rev.png" alt="WTSI" title="Wellcome Trust Sanger Institute" class="float-left" style="padding-left:20px" /></a>
    <a href="http://www.ebi.ac.uk"><img src="/img/ebi_new.gif" alt="EMBL-EBI" title="European BioInformatics Institute" class="float-right" style="padding-right:20px" /></a>
    &copy; $year <a href="http://www.sanger.ac.uk/" class="nowrap">WTSI</a> /
    <a href="http://www.ebi.ac.uk/" style="white-space:nowrap">EBI</a>.
    Ensembl is available to <a href="/info/downloads/index.html">download for public use</a> - please see the <a href="/info/code_licence.html">code licence</a> for details.
    </p>
    </div></div></div>
    ) 
  );
}

1;

