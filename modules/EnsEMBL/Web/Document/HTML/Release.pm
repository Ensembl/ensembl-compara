package EnsEMBL::Web::Document::HTML::Release;
use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;
@EnsEMBL::Web::Document::HTML::Release::ISA = qw(EnsEMBL::Web::Document::HTML);

sub new { return shift->SUPER::new( 'version' => '??', 'date' => '??? ????', 'site_name' => '??????' );}
sub version   :lvalue { $_[0]{'version'}; }
sub date      :lvalue { $_[0]{'date'}; }
sub site_name :lvalue { $_[0]{'site_name'}; }
sub render { 
  $_[0]->printf( qq(
<div id="release-t">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</div>
<div id="release"><div>
  %s release %s - <a href="/Multi/newsview?rel=%s" title="What's New">%s</a>
</div></div>), CGI::escapeHTML($_[0]->site_name), CGI::escapeHTML($_[0]->version), CGI::escapeHTML($_[0]->version), CGI::escapeHTML($_[0]->date)
  );;
}

1;

