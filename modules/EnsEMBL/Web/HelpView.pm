package EnsEMBL::Web::HelpView;

use EnsEMBL::Web::Document::Popup;
use EnsEMBL::Web::Document::Panel;
use EnsEMBL::Web::Document::Renderer::Apache;
use SpeciesDefs;
use strict;
use CGI;
use DBI;

use constant HELPVIEW_WIN_ATTRIBS => "width=700,height=550,resizable,scrollbars";
use constant HELPVIEW_IMAGE_DIR   => "/img/help";

#################################
# get and set index configuration
#################################

sub new {
  my( $class, $page ) = shift;
  my $cgi = new CGI;
  warn $cgi->param('kw');
  my $self = { 
    'cgi'  => $cgi,
    'kw'   => $cgi->param('kw')||'',
    'page' => new EnsEMBL::Web::Document::Popup( new EnsEMBL::Web::Document::Renderer::Apache ),
    'dbh'  => undef
  };
  bless $self, $class;
  return $self;
}

sub render { 
  my $self = shift;
  $self->{'cgi'}->header;
  warn keys %$self;
  $self->{'page'}->_initialize_HTML;
  if( $self->{'kw'} ) {
    if( $self->{'cgi'}->param( 'se' ) ) { ## Go into single entry mode....
      $self->show_page();
    } else { ## This is a full version of the search page... 
      $self->search_results();
    }
  } else {
    $self->null_search();
  }
  $self->set_up_menu();
## Set up the search box...
  $self->{'page'}->close->style = 'help';
  $self->{'page'}->close->URL   = "/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}";
  $self->{'page'}->close->kw    = $self->{'kw'};
  $self->{'page'}->helplink->label = 'Contact helpdesk';
  $self->{'page'}->helplink->URL = "mailto:".SpeciesDefs->ENSEMBL_HELPDESK_EMAIL;
  $self->{'page'}->menu->add_block( '___', 'bulleted', 'Help with help!' );
  $self->{'page'}->menu->add_entry( '___', 'href' => $self->_help_URL( 'helpview' ), 'text' => 'General' ) ;
  $self->{'page'}->menu->add_entry( '___', 'href' => $self->_help_URL( 'helpview#searching' ), 'text' => 'Full text search' );
  $self->{'page'}->render();
}

############################
# perform a full text search
############################

sub null_search {
  my $self = shift;
  $self->{'page'}->content->add_panel(
    EnsEMBL::Web::Document::Panel->new(
      'caption' => "Ensembl search",
      'content' => qq(
  <p>To start searching, either enter your keywords in the look up box above, or select one of the links on the 
    left hand side.</p>
    ))
  );
}

sub search_results {
  my $self = shift;
  my $results = $self->search_entries( $self->{'kw'} );
  if( @$results > 1 ) {
    $self->{'page'}->content->add_panel(
      EnsEMBL::Web::Document::Panel->new(
        'caption' => "Full text search",
        'content' => qq(
  <p>Your search for "$self->{'kw'}" is found in the following entries:</p>
  <ul>
    @{[ map { sprintf( '<li><a href="%s">%s</a></li>', $self->_help_URL($_->[2]), $_->[0] ) } @$results ]}
  </ul>)
      )
    );
  } elsif( @$results ) {
    $self->{'page'}->content->add_panel(
      EnsEMBL::Web::Document::Panel->new(
        'caption' => $results->[0][0],
        'content' => $self->link_mappings( $results->[0][1] )
      )
    );
  } else {
    $self->{'page'}->content->add_panel(
      EnsEMBL::Web::Document::Panel->new(
        'caption' => 'Ensembl search',
        'content' => qq(
  <p>
    Sorry, no sections matching '$self->{'kw'}'.
  </p>). (
   length( $self->{'kw'} )< 4 ? qq(
  <blockquote>Your search string must be at least 4 characters long.</blockquote>
      ) : '' )
      )
    );
  }
}

###########################
# print out a single result
###########################

sub show_page {
  my $self = shift;
  my $result = $self->select_entry( $self->{'kw'} );
 
  if( $result ) {
    $self->{'page'}->content->add_panel( 
      EnsEMBL::Web::Document::Panel->new(
        'caption' => $result->[0],
        'content' => $self->link_mappings( $result->[1] )
      )
    ); 
  } else {
    $self->{'page'}->content->add_panel(
      EnsEMBL::Web::Document::Panel->new(
        'caption' => 'Ensembl search',
        'content' => "Sorry, no sections matching '$self->{'kw'}'"
      )
    );
  }
}


#############################################
# print out all database entries, ie an index
#############################################


## Factory....

sub connect {
  my $self = shift;
  my $DB = SpeciesDefs->databases->{'ENSEMBL_HELP'};
  $self->{'dbh'} ||= DBI->connect(
    "DBI:mysql:database=$DB->{'NAME'};host=$DB->{'HOST'};port=$DB->{'PORT'}",
    $DB->{'USER'}, "$DB->{'PASS'}", { RaiseError => 1});

}

sub search_entries {
  my $self = shift;
  $self->connect;
  return $self->{'dbh'}->selectall_arrayref(
    "SELECT title, content, keyword, match (title, content) against (?) as score
       from article
     having score > 0
      order by score desc",
    {}, "%$self->{'kw'}%"
  );
}

sub select_entries {
  my $self = shift;
  $self->connect;
  return $self->{'dbh'}->selectall_arrayref(
    "SELECT a.title, a.keyword, c.name, c.priority
       FROM article a, category c where a.category_id = c.category_id
      ORDER by priority, name, title"
  );
}

sub select_entry {
  my( $self, $kw ) = @_;
  $self->connect;
  return $self->{'dbh'}->selectrow_arrayref( 
    "SELECT title, content FROM article WHERE keyword=?", {}, $kw
  );
}

## Configuration...

sub set_up_menu {
  my $self = shift;
  my $display_length = 34; #no of characters of the title that are to be displayed
  my $focus = $self->{'cgi'}->param('kw'); # get the current entry
  $focus =~ s/(.*)\#/$1/;
  my @result_array = @{ $self->select_entries() || [] };
  return qq(<p>Sorry, failed to retrieve results from help database</p>) unless @result_array;
  foreach my $row ( @result_array ) {
    (my $name = $row->[0] ) =~ s/^(.{50})...+/\1.../;
    $self->{'page'}->menu->add_block( lc($row->[2]), 'bulleted', $row->[2] );
    my %hash= ( 'text'    => $name );
       $hash{ 'title' } =  $row->[0] unless $name eq $row->[0];
    if( $row->[1] eq $focus ) { 
      $hash{ 'text'  } =  "$name";
    } else {
      $hash{ 'href'  } =  $self->_help_URL( $row->[1] );
    }
    $self->{'page'}->menu->add_entry( lc($row->[2]), %hash );
  }
}

##################
# return href text
##################

## Object

sub _help_URL {
  my( $self, $kw ) = @_;
  $ref = $self->{'object'}->param('referer')||$ENV{'HTTP_REFERERER'};
  $ref = CGI::escapeHTML( $ref );
  return "/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?se=1;kw=$kw;referer=$ref";
}

sub helplink {
  my( $self, $kw ) = @_;
  my $window_size = HELPVIEW_WIN_ATTRIBS;
  return "javascript:void(window.open('@{[$self->_help_URL($kw)]}','helpview','$window_size'));";
}

##########################
# do mapping substitutions
##########################

sub link_mappings {
  my $self = shift;
  my $content = shift;
     $content =~ s/HELP_(.*?)_HELP/$self->_help_URL($1)/mseg;
  my $replace = HELPVIEW_IMAGE_DIR;
     $content =~ s/IMG_(.*?)_IMG/$replace\/$1/mg;
  return $content;
}

1;
