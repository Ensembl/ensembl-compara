package EnsEMBL::Web::Submission;

use EnsEMBL::Web::GeneSubmission;
use EnsEMBL::Web::TransposonSubmission;

use vars qw(@ISA $AUTOLOAD);	
@ISA = qw(EnsEMBL::Web::GeneSubmission EnsEMBL::Web::TransposonSubmission);

use strict;
use EnsEMBL::Web::SpeciesDefs;  
use EnsEMBL::HTML::Page;
use CGI;
use DBI;
use Mail::Mailer;

my $species_defs =  new EnsEMBL::Web::SpeciesDefs();

sub new {
    my $class = shift;
    my $username = $species_defs->MOS_SUBMISSION->{'TRANSPOSON_USRNAME'};
	my $passwrd = $species_defs->MOS_SUBMISSION->{'TRANSPOSON_PSWD'};
#	my $database = $species_defs->MOS_SUBMISSION->{'TRANSPOSON_DATABASE'}."_test";
	my $database = $species_defs->MOS_SUBMISSION->{'TRANSPOSON_DATABASE'};
	my $port = $species_defs->MOS_SUBMISSION->{'TRANSPOSON_PORT'};
	my $host = $species_defs->MOS_SUBMISSION->{'TRANSPOSON_HOST'};
	
	my $trans_username = $species_defs->MOS_SUBMISSION->{'GENESUB_USRNAME'};
	my $trans_passwrd = $species_defs->MOS_SUBMISSION->{'GENESUB_PSWD'};
	my $trans_host = $species_defs->MOS_SUBMISSION->{'GENESUB_HOST'};
	my $trans_port = $species_defs->MOS_SUBMISSION->{'GENESUB_PORT'};
	my $trans_database = $species_defs->MOS_SUBMISSION->{'GENESUB_DATABASE'};
		
	my $self = { 
		'_script'  => "/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}",
    	'_cgi'     => new CGI,
    	'_CGI'     => {},
        '_dbh'     => DBI->connect( "dbi:mysql:database=$database;host=$host;port=$port" , "$username", "$passwrd", { RaiseError => 1 } ),
		'_submitter_dbh'   => DBI->connect( "dbi:mysql:database=$trans_database;host=$trans_host;port=$trans_port" , "$trans_username", "$trans_passwrd", { RaiseError => 1 } ),
        '_submitter_id' => 0,
    	'_constants' => $species_defs->MOS_SUBMISSION,
		'_static_html' => $species_defs->ENSEMBL_SERVERROOT."/modules/EnsEMBL/Web/submission/",  
		 
    };
    bless($self, $class);


    $self->getSubmitterFromCookie();    
    foreach( $self->{'_cgi'}->param() ) {
        ( $self->{'_CGI'}{$_} =  $self->{'_cgi'}->param( $_ ) ) =~ s/^\s*(.*?)\s*$/$1/s; ## Trim the input
        # print STDERR sprintf ">> %20s => %s\n", $_, $self->{'_CGI'}{$_}; # Diagnostic line - display all parameters!
    }
    return $self;
}

##################################################################################################
## SUPPORT FUNCTIONS........................................................................... ##
## chunked
## parameter
## parameters
## user
## redirect
## checkParameters
##################################################################################################

sub SubmitterAdaptor {
    my $self = shift; 
    return $self->{'_submitter_adaptor'}
        ||= Bio::EnsEMBL::Genename::DBSQL::SubmitterAdaptor->new($self->{'_submitter_dbh'});
}

sub chunked {
    my( $self, $string, $r, $join ) = @_;    
    $join||='<br \/>';
    $string =~ s/\s+//gsm;
    my $LHS = "(.{1,$r})";
    $string =~ s/$LHS/$1$join/gsm;
       $LHS = "$join(\s*$join)+";
    $string =~ s/$LHS/$join/gsm;
    
    return $string;
}

sub parameter {
    my ($self, $key, $value ) = @_;
    $self->{'_CGI'}{$key} = $value if defined($value);
    return $self->{'_CGI'}{$key};
}
sub parameters {
    my $self = shift;
    return keys( %{$self->{'_CGI'}} );
}

sub user {
    my ($self, $key, $value ) = @_;
	return unless $self->{'_submitter'};
    return $self->{'_submitter'}->first_name." ".$self->{'_submitter'}->name if $key eq 'fullname';
    return $self->{'_submitter'}->email if $key eq 'email';
    		$self->{'_submitter'}->$key($value) if defined($value);
    return $self->{'_submitter'}->$key;
}

sub redirect {
    my ($self,$action) = @_;
    print "Location: ".$species_defs->ENSEMBL_PROTOCOL."://".$species_defs->ENSEMBL_SERVERNAME.":".$species_defs->ENSEMBL_PROXY_PORT."/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?$action\n\n";
}

sub checkParameters {
    my($self,%parameter_hash) = @_;
    foreach( keys %parameter_hash ) {
        if($parameter_hash{$_}[0] eq 'required') {
            return "Missing required field: $parameter_hash{$_}[2] " unless $self->parameter($_) ;
        }
    }
    return '';
}
                
##################################################################################################
## USER IDENTIFICATION FUNCTIONS............................................................... ##
## encryptID
## decryptID
## getSubmitterFromCookie
## setCookie
##################################################################################################
sub encryptID {
    my $self = shift;
    my $ID = shift;
    my $rand1 = 0x8000000 + 0x7ffffff * rand();
    my $rand2 = $rand1 ^ ($ID + $self->{'_constants'}{'SUBMISSION_ENCRYPT_0'});
    my $encrypted =  
        crypt(crypt(crypt(sprintf("%x%x",$rand1,$rand2),$self->{'_constants'}{'SUBMISSION_ENCRYPT_1'}),$self->{'_constants'}{'SUBMISSION_ENCRYPT_2'}),
	$self->{'_constants'}{'SUBMISSION_ENCRYPT_3'});
    my $MD5d = Digest::MD5->new->add($encrypted)->hexdigest();
    
    return sprintf("%s%x%x%s", substr($MD5d,0,16), $rand1, $rand2, substr($MD5d,16,16));
}

sub decryptID {
    my $self = shift;
    my $encrypted = shift;
    my $rand1  = substr($encrypted,16,7);
    my $rand2  = substr($encrypted,23,7);
    my $ID = ( hex( $rand1 ) ^ hex( $rand2 ) ) - $self->{'_constants'}{'SUBMISSION_ENCRYPT_0'};
    my $XXXX =
    crypt(crypt(crypt($rand1.$rand2,$self->{'_constants'}{'SUBMISSION_ENCRYPT_1'}),
    	$self->{'_constants'}{'SUBMISSION_ENCRYPT_2'}),$self->{'_constants'}{'SUBMISSION_ENCRYPT_3'});
    my $MD5d = Digest::MD5->new->add($XXXX)->hexdigest();
    $ID = substr($MD5d,0,16).$rand1.$rand2.substr($MD5d,16,16) eq $encrypted ? $ID : 0;
}
   
sub getSubmitterFromCookie {
    my $self = shift;
    my %cookies = fetch CGI::Cookie;
    
    $self->{'_submitter_id'} =
    	$cookies{ $self->{'_constants'}{'SUBMISSION_COOKIE'} } &&
		$self->decryptID($cookies{ $self->{'_constants'}{'SUBMISSION_COOKIE'} }->value) || 0;
    $self->{'_submitter'} = $self->SubmitterAdaptor->fetch_submitter_by_db_id( $self->{'_submitter_id'} ) if($self->{'_submitter_id'});
    
    if( !$self->{'_submitter'} )  {
        $self->{'_submitter_id'} = 0;
    }
}

sub setCookie {
    my($self,$ID) = @_;
    my $cookie = new CGI::Cookie(
        -name    => $self->{'_constants'}{'SUBMISSION_COOKIE'},
        -value   => $self->encryptID($ID),
        -path    => '/',
        -domain  => $species_defs->ENSEMBL_COOKIEHOST,
        -expires => "Friday, 31-Dec-2010 23:59:59 GMT"
    );
    print "Set-Cookie: $cookie\n";
#    print STDERR $cookie;
}

##################################################################################################
## TEMPLATE FUNCTIONS.......................................................................... ##
## _tableStart
## _tableEnd
## TABLE
## expand
## column
## ddown
## script
## get_html_template
## page
##################################################################################################
sub _tableStart {
    my $self=shift;
    my $all_transposons = '';

    if ($self->user('is_admin')){
        $all_transposons = qq(<dt>&nbsp;<a href="[[SCRIPT]]?action=AllTransposons">All Transposons</a></dt>);}
    
    return $self->expand(qq(
	<table border="0" cellspacing="0" cellpadding="2" width="840">
	<tr valign="top">
  	  <td width="120" align="left" class="gs_nav" ><dl>
    <dt>&nbsp;</dt>
	<dt>[[SAFE::name]] &nbsp;</dt>
    <dt>&nbsp;</dt>
    <dt>&nbsp;<a href="[[SCRIPT]]?action=[[SAFE::logaction_txt]]">[[SAFE::logaction_txt]]</a></dt>
    <dt>&nbsp;</dt>
	<dt>&nbsp;<a href="/Anopheles_gambiae/">Home</a></dt>
	<dt>&nbsp;<a href="[[SCRIPT]]">Introduction</a></dt>
    <dt>&nbsp;<a href="[[SCRIPT]]?action=guide">Guidelines</a></dt>
    <dt>&nbsp;<a href="[[SCRIPT]]?action=help">Help pages</a></dt>
    <dt>&nbsp;<a href="[[SCRIPT]]?action=privacy">Privacy Policy</a></dt>
    <dt>&nbsp;</dt>  
    <dt>&nbsp;<a href="[[SCRIPT]]?action=AllTransposons">All Transposons</a></dt>
	<dt>&nbsp;<a href="[[SCRIPT]]?action=MyTransposons">My Transposons</a></dt>
	<dt>&nbsp;<a href="[[SCRIPT]]?action=AddTransposon">New Transposon</a></dt> 
	<dt>&nbsp;<a href="[[SCRIPT]]?action=TransposonSearchForm">Find Transposon</a></dt>    
    <dt>&nbsp;</dt>      
    <dt>&nbsp;<a href="[[SCRIPT]]?action=allgenes">All Genenames</a></dt>
    <dt>&nbsp;<a href="[[SCRIPT]]?action=mygenes">My Genenames</a></dt>
    <dt>&nbsp;<a href="[[SCRIPT]]?action=AddGene">New Genename</a></dt> 
	<dt>&nbsp;<a href="[[SCRIPT]]?action=GeneSearchForm">Find Genename</a></dt>
	<dt>&nbsp;</dt>
    <dt>&nbsp;<a href="[[SCRIPT]]?action=register">Register</a></dt>
    </dl></td><td width="620" align="center"><br/>
    <table align="center" border="0" cellspacing="0" cellpadding="0" width="596" class="background1">),
    'name'      => $self->user('submitter_id') ? $self->user('fullname') : '',
    'logaction_txt' => $self->user('submitter_id') ? 'Logout' : 'Login'
    );
}
   
sub _tableEnd { 
    my $self=shift;
    return $self->expand(qq(
    </table></td></tr></table><br/>)
    );
}

sub TABLE {
    my $self=shift;
    print 
        $self->{'_cgi'}->header(),
        ensembl_page_header(('initfocus'=>1)),
        ensembl_search_table(),
        $self->_tableStart(),
        $self->expand( @_ ),
        $self->_tableEnd(),
        ensembl_page_footer();
}

sub expand {
    my ($self,$string,%parameter) = @_;
    $string =~s/\[\[SAFE::([^\]]+)\]\]/CGI->escapeHTML($parameter{$1})/eg;
    $string =~s/\[\[URL::([^\]]+)\]\]/CGI->escape($parameter{$1})/eg;
    $string =~s/\[\[RAW::([^\]]+)\]\]/$parameter{$1}/eg;
    $string =~s/\[\[DDOWN::(.*?)::(.*?)::([^\]]+)\]\]/$self->ddown($parameter{$1},$parameter{$2},$parameter{$3})/eg;
    $string =~s/\[\[SCRIPT\]\]/$self->script/eg;
    $string =~s/\[\[COLM::(.*?)::([^\]]+)\]\]/$self->column($parameter{$1}, $parameter{$2})/eg;
    return $string;
}

sub column {
    my ($self, $num, $string) = @_;
    my $rows = '';
    my $counter = 0;
    my @lines = split ("<tr>", $string);    
    if (scalar(@lines) >= 20){
      for my $line (@lines){
         next if ($line != /\+w/g);
	     if ($counter == $num){ 
           $line = "</tr><tr>". $line ; 
           $counter = 1;
	   $rows = $rows . $line;
	   next;
         }
      $rows = $rows . $line;
      ++$counter;
      }    
	return $rows;
    }
    else {return $string;}
}

sub script { 
    my ($self, $value ) = @_;
    $self->{'_script'} = $value if defined($value);
    return $self->{'_script'};
}

sub ddown {
    my ($self,$name, $value, $values ) = @_;
    local $_;
    return join '',qq(<select name="$name">),
        map( { '<option'.($value eq $_ ? ' selected':'').'>'.CGI->escapeHTML($_).'</option>' } split ':',$values ),'</select>';
}

sub get_html_template {
    my( $self, $file ) = @_;
    local $/ = undef;
    open(FILE, $self->{_static_html}."$file") || warn("ANO_SUBMISSION: Can't open static HTML file: $!") ;
    my $text = <FILE>; 
    close FILE;
    return $text;
}

sub page {
  my( $self, $file, %params) = @_;
  $self->TABLE( $self->get_html_template( $file ), %params) ; 
}

##################################################################################################
## ACTION FUNCTIONS............................................................................ ##
## .._main
## .._register
## .._logout
## .._login
## .._mytransposons
## .._alltransposons
## .._addtransposon
## .._bulkadd
## .._updatetransposon
## .._transposon
## .._search
## .._search_form
##################################################################################################
sub ACTION_main {
    my $self = shift;
    $self->page( 'introduction.html' );   
}

sub ACTION_help {
    my $self = shift;
    $self->page( 'help.html' );
}

sub ACTION_privacy {
    my $self = shift;
    $self->page( 'privacy.html' );
}

sub ACTION_guide {
    my $self = shift;
    my $path = $self->parameter('guide' );
#	$path = '' if ($path ne 'transposon' || $path ne 'genesub');
	$self->page( "$path/guide.html" );
}

sub ACTION_register {
    my $self = shift;
    my $error = '';
    if( $self->parameter('register') == 1) {
    ## ERROR CHECKING
	$error = $self->checkParameters(
	    'firstname'     => [ 'required','','First Name' ],
        'lastname'      => [ 'required','','Last Name' ],
        'email'         => [ 'required','email','E-mail' ],
        'organisation'  => [ 'required','','Organisation' ],
        );
     if($error eq '') {
     # Register user and generate email
        my $password = join '',map { chr(ord('a')+int(rand(26))) } ( 1..(7+int(rand(3))) );
        my $user = Bio::EnsEMBL::Genename::Submitter->new( 
                -adaptor       => $self->SubmitterAdaptor(),
                -first_name    => $self->parameter('firstname' ),
                -name          => $self->parameter('lastname' ),
                -email         => $self->parameter('email' ),
                -password      => $password,
                -affiliation   => $self->parameter('organisation' ),
                -address       => ''.$self->parameter('address' ),
                );
        my $status = $user->adaptor->store( $user );
	    if($status == 2) {
               $self->setCookie( $user->submitter_id );
                $self->redirect( );
                my $mailer = new Mail::Mailer 'smtp', Server => "mail.sanger.ac.uk";
                $mailer->open({
        		    'To'      => $self->parameter('email' ),
        		    'Subject' => "Anopheles Ensembl Submission Registration",
                });
                print $mailer sprintf(
"Dear %s,

Your registration for the submission of Anopheles annotations has
been successful. You can now log in through the web interface with your email
address, and the supplied password:

   Email:       %s
   Password:    %s

Regards,

EnsEMBL Development Team.

", $self->parameter('firstname' ), $self->parameter('email' ), $password

);
        $mailer->close();
        return();
        }
	    $error = join (", ",$user->adaptor->err()) ;
	}
    $error = "<p><strong>$error</strong></p>";
    }
       
    $self->page( 'registration.html',  
    	'error'         => $error,
        'firstname'     => $self->parameter('firstname'),
        'lastname'      => $self->parameter('lastname'),
        'email'         => $self->parameter('email'),
        'organisation'  => $self->parameter('organisation'),
        'address'       => $self->parameter('address') );    
}
    
sub ACTION_Logout {
    my $self = shift;
    $self->setCookie( 0 );
    $self->redirect( );
}

#sub ACTION_Login {
#    my $self = shift;    
#	if( $self->parameter('Login') == 1 ) {
#        ## ERROR CHECKING
#        my $ID = $self->SubmitterAdaptor->get_user_id( $self->parameter('email'), $self->parameter('password') );
#        if( $ID ) {
#            $self->setCookie( $ID );
#            print STDERR "BG2".$self->parameter('task');
#			$self->redirect( $self->parameter('task') eq 'Login' ? '' : "action=".$self->parameter('task')  );
#            return;
#        }
#    }
#    
#    $self->page( 'login.html',
#        'email' => $self->parameter('email'),
#        'action' => $self->parameter('action'),
#    );
#}

1;
