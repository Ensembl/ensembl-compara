package EnsEMBL::Web::TransposonSubmission;

use Bio::EnsEMBL::Transposon::DBSQL::TransposonAdaptor;
use Bio::EnsEMBL::Genename::DBSQL::SubmitterAdaptor;
use Bio::EnsEMBL::Transposon::DBSQL::SequenceAdaptor;
use Bio::EnsEMBL::Transposon::DBSQL::FamilyAdaptor;
use Bio::EnsEMBL::Transposon::DBSQL::FeatureAdaptor;
use Bio::EnsEMBL::Transposon::DBSQL::SynonymAdaptor;
use Bio::EnsEMBL::Transposon::Transposon;
use Bio::EnsEMBL::Genename::Submitter;
use Bio::EnsEMBL::Transposon::Sequence;
use Bio::EnsEMBL::Transposon::Family;
use Bio::EnsEMBL::Transposon::Features;
use Bio::EnsEMBL::Transposon::Synonym;

use strict;
use EnsEMBL::Web::SpeciesDefs;  
use EnsEMBL::DB::Core;
use EnsEMBL::HTML::Page;
use CGI;
use DBI;
use Mail::Mailer;

my $species_defs =  new EnsEMBL::Web::SpeciesDefs();


##################################################################################################
## ADAPTOR FETCHING FUNCTIONS.................................................................. ##
## TransposonAdaptor
## SequenceAdaptor
## FamilyAdaptor
## SubmitterAdapator
## FeatureAdaptor
## SynonymAdaptor
##################################################################################################

sub SequenceAdaptor {
    my $self = shift; 
    return $self->{'_sequence_adaptor'}
        ||= Bio::EnsEMBL::Transposon::DBSQL::SequenceAdaptor->new($self->{'_dbh'});
}

sub TransposonAdaptor {
    my $self = shift; 
    return $self->{'_transposon_adaptor'}
        ||= Bio::EnsEMBL::Transposon::DBSQL::TransposonAdaptor->new($self->{'_dbh'});
}

sub FamilyAdaptor {
    my $self = shift; 
    return $self->{'_family_adaptor'}
        ||= Bio::EnsEMBL::Transposon::DBSQL::FamilyAdaptor->new($self->{'_dbh'});
}

sub FeatureAdaptor {
    my $self = shift; 
    return $self->{'_feature_adaptor'}
        ||= Bio::EnsEMBL::Transposon::DBSQL::FeatureAdaptor->new($self->{'_dbh'});
}

sub SynonymAdaptor {
    my $self = shift; 
    return $self->{'_synonym_adaptor'}
        ||= Bio::EnsEMBL::Transposon::DBSQL::SynonymAdaptor->new($self->{'_dbh'});
}

sub ACTION_Login {
    my $self = shift;    
	if( $self->parameter('Login') == 1 ) {
        ## ERROR CHECKING
        my $ID = $self->SubmitterAdaptor->get_user_id( $self->parameter('email'), $self->parameter('password') );
        if( $ID ) {
            $self->setCookie( $ID );
            $self->redirect( $self->parameter('task') eq 'Login' ? '' : "action=".$self->parameter('task')  );
            return;
        }
    }
    
    $self->page( 'transposon/login.html',
        'email' => $self->parameter('email'),
        'action' => $self->parameter('action'),
    );
}

sub ACTION_MyTransposons { 
    my $self = shift;
    return $self->ACTION_Login unless $self->user('submitter_id');
    
    if ($self->TransposonAdaptor()->fetch_transposon_by_submitter_id( $self->user('submitter_id') )){
        $self->TABLE(
qq(
    <tr class="black" valign="top">
		<td rowspan="5"><img src="/gfx/blank.gif" height="1" alt=""></td>
		<td><img src="/gfx/blank.gif" height="1" alt=""></td>
		<td rowspan="5"><img src="/gfx/blank.gif" height="1" alt=""></td>
	</tr>
	<tr class="background2"><td class="h5">&nbsp;My Transposons</td></tr>
	<tr class="black" valign="top"><td><img src="/gfx/blank.gif" height="1" alt=""></td></tr>
	<tr>
		<td class="gs_body">
			<table align="center" border="0" cellpadding="0" cellspacing="0" width="596" >
    		<tr><td colspan="3"><img src="/gfx/blank.gif" height="10" width="596" alt=""></td></tr>
			<tr>
				<td>&nbsp;&nbsp;</td>
				<td><p>You have submitted the following transposons:</p>
                <table width="500" align="center"><tr>[[COLM::num::transposons]]</tr></table>
            </td>
			<td>&nbsp;&nbsp;</td></tr>
				<tr><td colspan="3"><img src="/gfx/blank.gif" height="10" width="596" alt=""></td></tr>
			</table>
			</td></tr>
	<tr class="black" valign="top"><td><img src="/gfx/blank.gif" height="1" alt=""></td></tr>
        ),

	    'num' => 4,
	    'transposons' => join( '<tr>', map( {
			            $self->expand(
            		    qq(<td>
						
<a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=transposon&db_id=[[URL::transposon_id]]">[[SAFE::identifier]]</a></td>),
                'transposon_id' => $_->transposon_id, 'identifier'  => $_->identifier
            ) } $self->TransposonAdaptor()->fetch_transposon_by_submitter_id( $self->user('submitter_id') )
        ) ),
    );
	}
    
    else {
    $self->TABLE(
         qq(
	 <tr class="black" valign="top">
		<td rowspan="5"><img src="/gfx/blank.gif" height="1" alt=""></td>
		<td><img src="/gfx/blank.gif" height="1" alt=""></td>
		<td rowspan="5"><img src="/gfx/blank.gif" height="1" alt=""></td>
	</tr>
	<tr class="background2"><td class="h5">&nbsp;My Transposons</td></tr>
	<tr class="black" valign="top"><td><img src="/gfx/blank.gif" height="1" alt=""></td></tr>
	<tr>
		<td class="gs_body">
			<table align="center" border="0" cellpadding="0" cellspacing="0" width="596" >
    		<tr><td colspan="3"><img src="/gfx/blank.gif" height="10" width="596" alt=""></td></tr>
			<tr>
				<td>&nbsp;&nbsp;</td>
				<td><p><strong>You currently have no transposons entries in the database</strong></p>
	 <p>Please click <a href="[[SCRIPT]]?action=AddTransposon">here</a> to enter a new  transposon.</p>
	 </td><td>&nbsp;&nbsp;</td></tr>
				<tr><td colspan="3"><img src="/gfx/blank.gif" height="10" width="596" alt=""></td></tr>
			</table>
			</td></tr>
	<tr class="black" valign="top"><td><img src="/gfx/blank.gif" height="1" alt=""></td></tr>
    ))}
    return;
}

sub ACTION_AllTransposons{ 
    my $self = shift;
    
    $self->TABLE(
        qq(
    <tr class="black" valign="top">
		<td rowspan="5"><img src="/gfx/blank.gif" height="1" alt=""></td>
		<td><img src="/gfx/blank.gif" height="1" alt=""></td>
		<td rowspan="5"><img src="/gfx/blank.gif" height="1" alt=""></td>
	</tr>
	<tr class="background2"><td class="h5">&nbsp;All Submitted Transposons</td></tr>
	<tr class="black" valign="top"><td><img src="/gfx/blank.gif" height="1" alt=""></td></tr>
	<tr>
		<td class="gs_body">
			<table align="center" border="0" cellpadding="0" cellspacing="0" width="596" >
    		<tr><td colspan="3"><img src="/gfx/blank.gif" height="10" width="596" alt=""></td></tr>
			<tr>
				<td>&nbsp;&nbsp;</td>
				<td><p>All Transposons:</p>
                	<table width="500" align="center"><tr>[[COLM::num::transposons]]</tr></table>
           		 </td><td>&nbsp;&nbsp;</td></tr>
				<tr><td colspan="3"><img src="/gfx/blank.gif" height="10" width="596" alt=""></td></tr>
			</table>
			</td></tr>
	<tr class="black" valign="top"><td><img src="/gfx/blank.gif" height="1" alt=""></td></tr>
        ),

	    'num' => 4,
	    'transposons' => join( '<tr>', map( {
            $self->expand(
                qq(<td><a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=transposon&db_id=[[URL::transposon_id]]">[[SAFE::identifier]]</a></td>),
                'transposon_id' => $_->transposon_id, 'identifier'  => $_->identifier
            ) } $self->TransposonAdaptor()->fetch_all_transposons()
        ) ),
    );
    return;
}

sub ACTION_deleteTransposon { 
    my $self = shift;
    my $transposon = $self->TransposonAdaptor()->fetch_transposon_by_db_id( $self->parameter('db_id') );
        
    if (!$self->user('is_admin')){
       return $self->ACTION_transposon() if $transposon->get_submitter && $transposon->get_submitter->submitter_id != $self->user('submitter_id');}
    
    if ($self->parameter('del')){
		$self->TransposonAdaptor()->remove($transposon); 
		$self->transposon_EMAIL($transposon, 'delete');
		if ($self->user('is_admin')){ return $self->ACTION_AllTransposons(); }
   		else { return $self->ACTION_MyTransposons(); } 
    }
        	
    $self->page( 'transposon/delete.html',
        'path'			=> $self->{'_constants'}{'GFX_BUTTONS'} ,
		'transposon_id' => $transposon->transposon_id,
        'identifier'    => $transposon->identifier,						
    );
}

sub ACTION_transposon {
    my $self = shift;
    my $db_id = $self->parameter('db_id'); 
    my $identifier = $self->parameter('identifier');
    my $transposon;
    my $ensembl_geneview_link = '';  # change to new transposon view link when created 
    my $ensembl_location = '';
    
    $transposon = $self->TransposonAdaptor()->fetch_transposon_by_db_id( $db_id,  $self->parameter('version') ) if ($db_id);
    $transposon = $self->TransposonAdaptor()->fetch_transposon_by_identifier( $identifier,  $self->parameter('version') ) if ($identifier) ;
    return $self->ACTION_unknownTransposon($identifier) unless ($transposon);
    
    my ($editing, $addfeature, $addsynonym) = '';
    my $error ;
    my $submitter_email ;

    $identifier = $transposon->identifier;
    
#	non-critical error messages    
#    if ($self->parameter('message') =~ /orf/g){
#		$error .= qq(	<tr>
#				<td>&nbsp;&nbsp;</td>
#				<td class="gs_req"><b>NOTICE:</b> Sequence has reading frame < 50 aa, but HAS been added to the database.<br/></td>
#				<td>&nbsp;&nbsp;</td>
#				</tr>);}

#	if owner of gene or admin, add edit links				            
    if ($self->user('is_admin') || $transposon->get_submitter->submitter_id == $self->user('submitter_id')){
		$editing = qq(
		<br /><table align="right">
		<tr>
	 		<td>
		  	<a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=UpdateTransposon&db_id=$transposon->{transposon_id}"><img src="$self->{'_constants'}{'GFX_BUTTONS'}/edit.gif" border='0' alt="Edit"></a>
			 &nbsp;&nbsp;</td>
	 		<td>
	  		<a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=deleteTransposon&db_id=$transposon->{transposon_id}"> <img src="$self->{'_constants'}{'GFX_BUTTONS'}/delete.gif" border='0' alt="Delete"></a>
	 		</td> 
        </tr>
		</table>);
#### change add feature button text
		$addfeature = qq(<td valign="top">
			<a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=UpdateTransposon&addfeature=1&db_id=$transposon->{transposon_id}">
			<img src="$self->{'_constants'}{'GFX_BUTTONS'}/add_feature.gif" border='0' alt="Add Feature">  </a>
		     </td>);
    	$addsynonym = qq(<td valign="top">
			<a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=UpdateTransposon&addsyn=1&db_id=$transposon->{transposon_id}">
			<img src="$self->{'_constants'}{'GFX_BUTTONS'}/add_syn.gif" border='0' alt="Add Synonym">  </a>
		     </td>);    	
	}		

#	if  admin show submitter e-mail				                
    $submitter_email = $transposon->get_submitter->email() if ($self->user('is_admin'));
           	
    $self->page( 'transposon/transposon.html',
    	'name'          => ($transposon->get_submitter->first_name)." ".($transposon->get_submitter->name),
        'affiliation'   => $transposon->get_submitter->affiliation,
        'identifier'    => $identifier,        
        'version'       => $transposon->version,       
		'error'			=> $error,	
        'features'		=> join( '', map( {
            $self->expand(
                '<tr>
					<td>[[SAFE::feature]]</td>
					<td>&nbsp;</td>
					<td>[[SAFE::location]]</td>
				</tr>',
                                
                'feature'  => $_->feature,
				'location' => $_->start." - ". $_->end,
            ) } $transposon->get_all_features()
        ) ),
		
		'synonyms'		=> join( '', map( { 
			$self->expand(
            		qq(	<li>&nbsp; [[SAFE::synonym]]</li>),                                								
							
							'synonym'	=> $_->synonym,	
				    ) } $transposon->get_all_synonyms()) ),	
								
        'sequences'     => join( '', map( {
            $self->expand(
                '<pre>[[RAW::sequence]]</pre></dd></dl>',                                
                'sequence' => uc($self->chunked($_->sequence,40)),
            ) } $transposon->get_all_sequence()
        ) ),
	
		'editing'		=> $editing,
		'addfeature'	=> $addfeature,
		'addsynonym'	=> $addsynonym,
		'submitter_email' => $submitter_email,
		'geneview' 		=> $ensembl_geneview_link,
		'family'		=> ($transposon->get_family()->name || ''),
	 );
}

sub transposon_EMAIL {
    my $self = shift;
    my $transposon = shift;
    my $call = shift;
    my $old_transposon;
    my $admin_modification = '';
    my $mailer = new Mail::Mailer 'smtp', Server => "mail.sanger.ac.uk";
    
    ### Find Transposon information for previous Transposon to build UPDATE E-mail
	my $transposon_id = $transposon->transposon_id;

	$old_transposon = $self->TransposonAdaptor->fetch_transposon_by_db_id($transposon_id, $self->TransposonAdaptor->get_max_version($transposon_id));

    $admin_modification = "by ". $self->user('fullname')."(administrator)" if ($self->user('is_admin'));
	
    my ($message, $subject, $modification) = '';
    if($call eq 'add'){
    	$message = qq(\nThank you for submitting to EnsEMBL, we confirm the following Anopheles transposon submission: \n );
    	$subject = "Transposon Submission: ";
    }
    if($call eq 'delete'){
    	$message = qq(\nThe following transposon has been deleted from the Anopheles EnsEMBL database $admin_modification : \n);
    	$subject = "Transposon Deletion: ";
    }
    if($call eq 'update'){
    	$message = qq(\nThe transposon [[SAFE::identifier]] in the Anopheles EnsEMBL database has been modified $admin_modification to: \n);
    	$subject = "Transposon Modification: ";
    
    }
    
    $mailer->open({
            'To'        => $self->{'_constants'}{'SUBMISSION_EMAIL'},
	    	'Cc' 	=> $transposon->get_submitter->email, 
            'Subject'   => "$subject".$transposon->identifier." (".$transposon->transposon_id.")",
    });
    print $mailer $self->expand(qq(

Dear [[SAFE::name]],
$message

Submitter:      [[SAFE::name]] ([[SAFE::affiliation]])
Identifier:  	[[SAFE::identifier]]
Family:      	[[SAFE::Family]]
Synonyms:		[[SAFE::Family]]
Features:		[[SAFE::Family]]

Sequence:
[[RAW::sequences]]

$modification
Kind regards,

EnsEMBL Development Team.
        ),
        'name'          => ($transposon->get_submitter->first_name)." ".($transposon->get_submitter->name),
        'affiliation'   => $transposon->get_submitter->affiliation,
        'identifier'    => $transposon->identifier,
        'Family'   		=> $transposon->get_family()->name,        
        'features'		=> join( '\n', map( {$_} $transposon->get_all_features() ) ),
		'synonyms'		=> join( '\n', map( {$_} $transposon->get_all_synonyms() ) ),
		'sequences'     => join( '\n', map( {
            $self->expand(                
                          "[[RAW::sequence]]\n",                                
                'sequence' => $self->chunked($_->sequence,60,"\n"),
            ) } $transposon->get_all_sequence()
        ) ),
		'identifier'        => $old_transposon->identifier,
    );
    $mailer->close;
}

sub ACTION_UpdateTransposon{
    my $self = shift;
    my $warning = '';
    my $message ; 
    my $success = 0;
    my $transposon;
    my $seq_no_ws;
       
    return $self->ACTION_Login unless $self->user('submitter_id');
    my $page = 'update.html' ;
	$page = 'add_feature.html'if ($self->parameter('addfeature'));
	$page = 'add_synonym.html'if ($self->parameter('addsyn'));
	    	
    eval {$transposon = $self->TransposonAdaptor()->fetch_transposon_by_db_id( $self->parameter( 'db_id' ) );};
    
    if( $transposon ) {
       if (!$self->user('is_admin')){
       return $self->ACTION_transposon() if $transposon->get_submitter && $transposon->get_submitter->submitter_id != $self->user('submitter_id');}
    }
    else {return $self->ACTION_AddTransposon();}
    my @families = @{$self->FamilyAdaptor->get_all_families()}; 
	my ($family_match) = grep {$_->name eq $self->parameter('family')} @families;   
    if ($self->parameter('update') == 1){			
		$transposon->identifier( $self->parameter('identifier') || $transposon->identifier);
                
# Sequences       
		foreach my $sequence ( $transposon->get_all_sequence() ) {
    		($seq_no_ws = $self->parameter('sequence' )) =~ s/\s+//g;  
			$sequence->sequence($seq_no_ws);
	  	}  
# features       
        
		foreach my $feature ( $transposon->get_all_features() ) {            
			 $feature->feature( $self->parameter( 'feature_'.$feature->trans_feature_id, ) );
			 $feature->start( $self->parameter( "start_".$feature->trans_feature_id, ) );
			 $feature->end( $self->parameter( "end_".$feature->trans_feature_id, ) );		
		}
		
# features (addfeature)
		if( $self->parameter('start_0') && $self->parameter('start_0') ne '' &&  $self->parameter('end_0') && $self->parameter('end_0') ne '') {
            $transposon->add_feature(
                Bio::EnsEMBL::Transposon::Features->new( 
                    -adaptor        => $self->FeatureAdaptor(),
                    -feature       	=> $self->parameter('feature_0'),
					-start			=> $self->parameter('start_0'),
					-end			=> $self->parameter('end_0'),	
                ));   
        }	
			
# synonyms       
        foreach my $synonym ( $transposon->get_all_synonyms() ) {
			$synonym->synonym( $self->parameter( "synonym_".$synonym->synonym_id) );
			$synonym->synonym_id ($synonym->synonym_id );	
		}          
		
# Synonyms (addsyn)
		if( $self->parameter('synonym_0') && $self->parameter('synonym_0') ne '' ) {
            $transposon->add_synonym(
                Bio::EnsEMBL::Transposon::Synonym->new( 
                    -adaptor	=>	$self->SynonymAdaptor,
					-transposon_id => $transposon->transposon_id ,
					-synonym  => $self->parameter('synonym_0' )
                ));   
        }	
#family 
		$transposon->family_id( $family_match ? $family_match->family_id : $transposon->family_id) ;
	
		if($transposon->transposon_id) {
        if ($success = $transposon->update()){  
		if ($self->parameter('family') eq 'Other'){
			print "Location: /$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=AddFamily&db_id=".$transposon->transposon_id ;
			return;		
		} 	
			print "Location: /$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=transposon&db_id=".$transposon->transposon_id."&message=".$message ;
		 	$self->transposon_EMAIL($transposon, 'update');
            return;
	    }
        else {
	     	$warning = "<b>WARNING: </b>". join ("<br/>",$self->SequenceAdaptor->err()) if ($self->SequenceAdaptor->err());
			$warning = "<b>WARNING: </b>". join ("<br/>",$self->TransposonAdaptor->err()) if ($self->TransposonAdaptor->err());
			$warning = "<b>WARNING</b><br/> ". join ("<br/> ",$self->FeatureAdaptor->err()) if ($self->FeatureAdaptor->err());
			$warning = "<b>WARNING</b><br/> ". join ("<br/> ",$self->SynonymAdaptor->err()) if ($self->SynonymAdaptor->err());
	    }         
		}}
#if not update make everything read only except the 'add' item
	$self->page( 'transposon/'.$page ,
    
        'name'          => $self->user( 'fullname' ),
        'affiliation'   => $self->user( 'affiliation' ),
        'transposon_id' => $transposon->transposon_id,
        'identifier'    => $transposon->identifier,
       	'family_list'	=> join( ':', map( { $_->name} @families), 'Other' ),			
		'family'		=> 'family',
		'family_0'		=> $transposon->get_family()->name,        
		'ro_features'	=> join( '', map( { $self->expand(               
                           qq(<tr>
		  						<td>[[SAFE::feature_0]]&nbsp;&nbsp;<input type="hidden" name="[[RAW::feature_id]]" size="6" value="[[RAW::feature_0]]"></td>
								<td>[[RAW::start]] <input type="hidden" name="[[RAW::start_id]]" size="6" value="[[RAW::start]]"></td>
								<td>- &nbsp;[[RAW::end]]<input type="hidden" name="[[RAW::end_id]]" size="6" value="[[RAW::end]]"></td>
		 					</tr>),                
            'feature_id'		=> 'feature_'.$_->trans_feature_id,	
			'start_id'			=> 'start_'.$_->trans_feature_id,
			'end_id'			=> 'end_'.$_->trans_feature_id,            	
			'feature_0'		=> $_->feature,	
			'start'			=> $_->start,
			'end'			=> $_->end,			
        ) } $transposon->get_all_features()) ),	
				
		'features' 		=> join( '', map( { $self->expand(               
                           qq(<tr>
		  						<td>[[DDOWN::feature::feature_0::feature_list]]</td>
								<td><input type="text" name="[[RAW::start_id]]" size="6" value="[[RAW::start]]"> - </td>
								<td>&nbsp; <input type="text" name="[[RAW::end_id]]" size="6" value="[[RAW::end]]"></td>
		 					</tr>),                
                
        	'feature_list'	=> join( ':', map( { $_->feature} @{$self->FeatureAdaptor->get_all_features()}) ),			
			'feature'		=> 'feature_'.$_->trans_feature_id,,
			'feature_0'		=> $_->feature,	
			'start'			=> $_->start,
			'end'			=> $_->end,
			'start_id'		=> 'start_'.$_->trans_feature_id,,
			'end_id'		=> 'end_'.$_->trans_feature_id,,
        ) } $transposon->get_all_features()) ),	
		'add_feature'	=> $self->expand( qq(<tr>
												<td>[[DDOWN::feature::feature_0::feature_list]]</td>
												<td><input type="text" name="start_0" size="6" value="[[RAW::start_0]]"> - </td>
												<td>&nbsp; <input type="text" name="end_0" size="6" value="[[RAW::end_0]]"></td>
											</tr>),
			'feature'		=> 'feature_0',
			'feature_list'	=> join( ':', map( { $_->feature} @{$self->FeatureAdaptor->get_all_features()}) ),
			'feature_0'		=> 	$self->parameter('feature'),
			'start_0'		=> 	$self->parameter('start_0'),
			'end_0'			=> 	$self->parameter('end_0'),),
		
		'ro_Synonyms'	=> join( '', map( { $self->expand(                
                          	qq(	<li>&nbsp; [[RAW::synonym]] 
								<input type="hidden" name="[[RAW::synonym_id]]" value="[[SAFE::synonym]]">
								</li>),                                				
			'synonym_id'		=> 'synonym_'.$_->synonym_id,
			'synonym'			=> $_->synonym,					
        ) } $transposon->get_all_synonyms()) ),	
			
		'add_synonym'	=> $self->expand( qq(<li><input type="text" name="synonym_0" size="14" value="[[RAW::synonym_0]]"></li>),
			'synonym_0'		=> 	$self->parameter('synonym_0'),),				
		'Synonyms'		=> join( '', map( { $self->expand(                
                          	qq(	<li>&nbsp; <input type="text" name="[[RAW::synonym_id]]" size="14" value="[[RAW::synonym]]"></li>),                                	
			'synonym_id'		=> "synonym_".$_->synonym_id,
			'synonym'			=> $_->synonym,					
        ) } $transposon->get_all_synonyms()) ),	
				
		'sequences'      => join( '', map( {
            $self->expand(
            qq(<tr><td colspan="4"><textarea cols="40" rows="8" name="sequence">[[RAW::sequence]]</textarea></td></tr>),                
                'sequence'    => $self->chunked($_->sequence,40,"\n"),
             ) } $transposon->get_all_sequence()
        ) ),
		'ro_sequences'      => join( '', map( {
            $self->expand(
            qq(<tr><td colspan="4"><p><pre>[[RAW::sequence]] </pre>
	    		<input type="hidden" name="sequence" value="[[RAW::sequence]]"></td></tr>),                
                'sequence'    => $self->chunked($_->sequence,40,"\n"),
             ) } $transposon->get_all_sequence()
        ) ),        
		'sequence'    => uc($seq_no_ws),
        'error'         => $warning,	
    );
}

sub ACTION_AddTransposon{
    my $self = shift;
    my $success = 1; 
    my $warning;            
    my $transposon;
    my $seq_no_ws;
    my $message = '';
    
    return $self->ACTION_Login unless $self->user('submitter_id'); # pass to login if no user  
    
	my @families = @{$self->FamilyAdaptor->get_all_families()};	
    $transposon = Bio::EnsEMBL::Transposon::Transposon->new(                  #create new Transposon object
        -adaptor        =>  $self->TransposonAdaptor() || undef,                   
        -submitter_id   =>  $self->user('submitter_id') || undef,
        -identifier     =>  $self->parameter('identifier') || undef,	
    );
  	if ($self->parameter('submitted')){
  
# Sequences 
    ($seq_no_ws = $self->parameter('sequence_0')) =~ s/\s+//g;  		
	if( $self->parameter('sequence_0') && $self->parameter('sequence_0') ne '' ) {
	    $transposon->add_sequence(
                Bio::EnsEMBL::Transposon::Sequence->new( 
                    -adaptor        => $self->SequenceAdaptor(),
                    -sequence       => $seq_no_ws,
                ));
        }

# Features		
	if( $self->parameter('feature') && $self->parameter('start') ne '' && $self->parameter('end') ne '') {
	    $transposon->add_feature(
                Bio::EnsEMBL::Transposon::Features->new( 
                    -adaptor        => $self->FeatureAdaptor(),
                    -feature       	=> $self->parameter('feature'),
					-start			=> $self->parameter('start'),
					-end			=> $self->parameter('end'),					 
                ));
        }
		
#family		
	    my ($family_obj) = grep {$_->name eq $self->parameter('family')} @families;
		$transposon->family_id($family_obj->family_id) unless ($self->parameter('family') eq 'Other'); 

#synonym
	if( $self->parameter('synonym') && $self->parameter('synonym') ne '' ) {
	    $transposon->add_synonym(
                Bio::EnsEMBL::Transposon::Synonym->new( 
                    -adaptor        => $self->SynonymAdaptor(),
                    -synonym       	=> $self->parameter('synonym'),									 
                ));
        }
	    		                 
		if($success = $transposon->store()){  
		my @sequence = $transposon->get_all_sequence;
				
		if ($self->parameter('family') eq 'Other'){
			print "Location: /$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=AddFamily&db_id=".$transposon->transposon_id ;
			return;		
		}
		
		print "Location: /$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=transposon&db_id=".$transposon->transposon_id."&message=".$message ;
		$self->transposon_EMAIL($transposon, 'add');
		return;
             }
	     else {
	     	$warning = "<b>WARNING:</b><br/> ". join ("<br/> ",$self->SequenceAdaptor->err()) if ($self->SequenceAdaptor->err());
			$warning = "<b>WARNING</b><br/> ". join ("<br/> ",$self->TransposonAdaptor->err()) if ($self->TransposonAdaptor->err());
			$warning = "<b>WARNING</b><br/> ". join ("<br/> ",$self->FeatureAdaptor->err()) if ($self->FeatureAdaptor->err());
			$warning = "<b>WARNING</b><br/> ". join ("<br/> ",$self->SynonymAdaptor->err()) if ($self->SynonymAdaptor->err());
	     }	 
	$transposon->transposon_id(0);
  	}

    $self->page( 'transposon/add.html',    
        'error'         => $warning,
        'name'          => $self->user( 'fullname' ),
        'affiliation'   => $self->user( 'affiliation' ),
        'trans_id'      => $transposon->transposon_id,
        'identifier'    => $self->parameter('identifier'),
        'version'       => $transposon->version,
		'synonym'		=> $self->parameter('synonym'),
		'feature'		=> 'feature',
		'feature_0'		=> $self->parameter('feature'),
		'feature_list'	=> join( ':', map( { $_->feature} @{$self->FeatureAdaptor->get_all_features()}) ),  
		'start'			=> $self->parameter('start'),
		'end'			=> $self->parameter('end'),
		'sequence_0'    => uc($seq_no_ws),
		'family_list'	=> join( ':', map( { $_->name} @families), 'Other' ),			
		'family'		=> 'family',
		'family_0'		=> $self->parameter('family'),
    );
}
 
sub ACTION_AddFamily{
	my $self = shift;
    my $error = 0;
    my $warning = "";
	my $transposon ;
    eval {$transposon = $self->TransposonAdaptor()->fetch_transposon_by_db_id( $self->parameter( 'db_id' ) );};
	if ($self->parameter( 'added' )){
		if( $self->parameter('family')) {
            $transposon->add_family(
                Bio::EnsEMBL::Transposon::Family->new( 
                    -adaptor => $self->FamilyAdaptor(),
                    -name    => $self->parameter('family'),
                ));   
    	}
		print "Location: /$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=transposon&db_id=".$transposon->transposon_id if ($transposon->update());		
	}
	
	$self->TABLE(
        qq( <form action="[[SCRIPT]]" method="post">
  		<input type="hidden" name="action" value="AddFamily">
  		<input type="hidden" name="added" value="1">
  		<input type="hidden" name="db_id" value="[[SAFE::transposon_id]]">
		<tr class="black" valign="top">
	<td rowspan="5"><img src="/gfx/blank.gif" height="1" alt=""></td>
	<td><img src="/gfx/blank.gif" height="1" alt=""></td>
	<td rowspan="5"><img src="/gfx/blank.gif" height="1" alt=""></td>
</tr>
<tr class="background2"><td class="h5">&nbsp;Add Transposon Family</td></tr>
<tr class="black" valign="top"><td><img src="/gfx/blank.gif" height="1" alt=""></td></tr>
<tr>
	<td class="gs_body">
	<table align="center" border="0" cellpadding="0" cellspacing="0" width="596" >
    	<tr><td colspan="3"><img src="/gfx/blank.gif" height="10" width="596" alt=""></td></tr>
		<tr>
			<td>&nbsp;&nbsp;</td>
			<td><p>
A new transposon family should be submitted for your transposon. As this family name will be used for further submission please follow the naming convention for transposon families and make sure that
the family name is entered correctly. Please enter the family name of the transposon in the box below and click submit.</b>.<br />
  </p>
    <p class="gs_req">[[RAW::error]]</p>
    <table border="0" cellspacing="0" cellpadding="2">
    <tr valign="top">
      <td class="gs_req" align="right" width="150">Transposon:</td>
      <td class="gs_body" width="442">[[SAFE::transposon]]</td>
    </tr>
	<tr valign="top">
      <td class="gs_req" align="right" width="150">Family name:</td>
      <td class="gs_body" width="442"><input type="text" size="20" name="family" value="[[SAFE::familyname]]" ></td>
    </tr>
	<tr valign="top">
      <td colspan="2" align="center" class="gs_req" align="right"><input type="submit" value="Submit"></td>
    </tr>
    </table>
    </td><td>&nbsp;&nbsp;</td></tr>
		<tr><td colspan="3"><img src="/gfx/blank.gif" height="10" width="596" alt=""></td></tr>
	</table>
</td></tr>
<tr class="black" valign="top"><td><img src="/gfx/blank.gif" height="1" alt=""></td></tr>
  </form>),
  		
		'transposon'    => $transposon->identifier(),
        'familyname'    => $self->parameter( 'family' ),
		'transposon_id' => $self->parameter( 'db_id' ),        
  );       
}

#fix submission parser
sub ACTION_bulkaddTransposon{
    my $self = shift;
    my $error = 0;
    my $warning = "";
    my $found_header = 0;
    my $file = $self->parameter('transposon_file') ;
    my %transposons;
    my $transposon;
    
    return $self->ACTION_Login unless $self->user('submitter_id'); # pass to login if no user 
	my @families = @{$self->FamilyAdaptor->get_all_families()};

    if ($self->parameter('upload') && $self->parameter('transposon_file')){    	
		%transposons = $self->TransposonAdaptor->Parse_FastA($file);	
    	for my $transposon_identifier (keys %transposons){
    		$transposon = Bio::EnsEMBL::Transposon::Transposon->new(                 
       			 -adaptor        =>  $self->TransposonAdaptor(),                   
        		 -submitter_id   =>  $self->user('submitter_id'),        
        		 -identifier     =>  $transposon_identifier,
        		 -family_id		 =>  undef,
    		);
    	
	my $sequence = $transposons{$transposon_identifier}{'sequence'}	;	
	$transposon->add_sequence(
            Bio::EnsEMBL::Transposon::Sequence->new( 
                  -adaptor        => $self->SequenceAdaptor(),
                  -sequence       => $sequence,           
            )
    );
    	
	my $family = $transposons{$transposon_identifier}{'family'}	;	
	my ($family_obj) = grep {$_->name eq $family} @families;	
	if (!$family_obj){	
       my $new_family =  Bio::EnsEMBL::Transposon::Family->new( 
                    -adaptor => $self->FamilyAdaptor(),
                    -name    => $family,  					       
                    );
	$self->FamilyAdaptor->store($new_family);
	
    }		
	my $family_id = $self->FamilyAdaptor->exist($family);
	$transposon->family_id($family_id);
	$transposon->update();
		
    my $success = $transposon->store();
    if (!$success){
    	$warning .= "<b>Transposon $transposon_identifier not added to database:</b><br>";
    	$warning .= join ("<br> ",$self->TransposonAdaptor->err()) ."<p class='gs_req'>" if $self->TransposonAdaptor->err();
    	$warning .= join ("<br> ",$self->SequenceAdaptor->err()) ."<p class='gs_req'>" if $self->SequenceAdaptor->err();}
    	$self->TransposonAdaptor->flush_err();
    	$self->SequenceAdaptor->flush_err();
    }  	
	
	if ($warning){$error = 1;}
    else{print "Location: /$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=MyTransposons";}
	}    
   	$warning = "Please enter a file name to upload" if ($self->parameter('upload') && !$self->parameter('transposon_file'));
    
    if (!$error){	    
   		$self->page( 'transposon/bulk_submit.html', 	
			'error'         => $warning,    
    );
}
else {
	$self->TABLE(
		qq(<tr class="black" valign="top">
	<td rowspan="6"><img src="/gfx/blank.gif" height="1" alt=""></td>
	<td><img src="/gfx/blank.gif" height="1" alt=""></td>
	<td rowspan="6"><img src="/gfx/blank.gif" height="1" alt=""></td>
  </tr>
  <tr class="background2"><td class="h5">&nbsp;Bulk Transposon Submission</td></tr>
  <tr class="black" valign="top"><td><img src="/gfx/blank.gif" height="1" alt=""></td></tr>
  <tr>
	<td class="gs_body">
	<table align="center" border="0" cellpadding="0" cellspacing="0" width="596" >
    	<tr><td colspan="3"><img src="/gfx/blank.gif" height="10" width="596" alt=""></td></tr>
		<tr>
			<td>&nbsp;&nbsp;</td>
  			<td><p>Your file contained errors:
      		<p class="gs_req">[[RAW::error]]</p>
      		</td>
     	</tr>
     	<tr valign="top">
      		<td colspan="2" align="center" class="gs_req" align="right"><br/><a href="[[SCRIPT]]?action=MyTransposons">View Transposons</a></td>
     	</tr>
    </table>
    </td></tr>
	<tr class="black" valign="top"><td><img src="/gfx/blank.gif" height="1" alt=""></td></tr>
	),
	'error'         => $warning,
    	);
   }
}
# add synonym and feature search
sub ACTION_TransposonSearch{
	my $self = shift;
	my @transposons = ();
	my ($search_adaptor, $submitter_adaptor) = '';
	my @search;
			
	print "Location:/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=TransposonSearchForm&error=No search term entered" if (!$self->parameter('search_word'));	
			
	if ($self->parameter('subject') eq 'Transposon'){$search_adaptor = "search_transposon_by_identifier";}
	elsif ($self->parameter('subject') eq 'Submitter'){$submitter_adaptor = "search_submitter_like_name";}
	elsif ($self->parameter('subject') eq 'Organisation'){$submitter_adaptor = "search_submitter_like_organisation";}
	elsif ($self->parameter('subject') eq 'Family'){$search_adaptor = "fetch_transposon_by_family";}
	else {return $self->ACTION_AllTransposons;}
	
	my $date = $self->parameter('year').'-'.$self->parameter('month').'-'.$self->parameter('day') ;
	my $submission_id = $self->TransposonAdaptor()->get_submission_id_by_date($date);
	if ($submitter_adaptor) {
		my $submitters	= $self->SubmitterAdaptor()->$submitter_adaptor($self->parameter('search_word')) ;
		foreach my $submitter (@$submitters){			
			push @search, $self->TransposonAdaptor()->fetch_transposon_by_submitter_id($submitter);			
		}		
	} else {
		@search = $self->TransposonAdaptor()->$search_adaptor( $self->parameter('search_word'), $self->parameter('version'), $submission_id);
	}
	
	if (!@search ){
	   $self->TABLE(
           qq(
            <tr class="black" valign="top">
		<td rowspan="5"><img src="/gfx/blank.gif" height="1" alt=""></td>
		<td><img src="/gfx/blank.gif" height="1" alt=""></td>
		<td rowspan="5"><img src="/gfx/blank.gif" height="1" alt=""></td>
	</tr>
	<tr class="background2"><td class="h5">&nbsp;Search Results</td></tr>
	<tr class="black" valign="top"><td><img src="/gfx/blank.gif" height="1" alt=""></td></tr>
	<tr>
		<td class="gs_body">
			<table align="center" border="0" cellpadding="0" cellspacing="0" width="596" >
    		<tr><td colspan="3"><img src="/gfx/blank.gif" height="10" width="596" alt=""></td></tr>
			<tr>
				<td>&nbsp;&nbsp;</td>
				<td><p><b>Your search did not return any hits:</b><br/><br/>
			Click <a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=TransposonSearchForm">here</a> to search again</p>
            </td><td>&nbsp;&nbsp;</td></tr>
			<tr><td colspan="3"><img src="/gfx/blank.gif" height="10" width="596" alt=""></td></tr>
			</table>
		</td></tr>
	 <tr class="black" valign="top"><td><img src="/gfx/blank.gif" height="1" alt=""></td></tr>))
	   }
	
	else{
		$self->TABLE(
        qq(
            <tr class="black" valign="top">
		<td rowspan="5"><img src="/gfx/blank.gif" height="1" alt=""></td>
		<td><img src="/gfx/blank.gif" height="1" alt=""></td>
		<td rowspan="5"><img src="/gfx/blank.gif" height="1" alt=""></td>
	</tr>
	<tr class="background2"><td class="h5">&nbsp;Search Results</td></tr>
	<tr class="black" valign="top"><td><img src="/gfx/blank.gif" height="1" alt=""></td></tr>
	<tr>
		<td class="gs_body">
			<table align="center" border="0" cellpadding="0" cellspacing="0" width="596" >
    		<tr><td colspan="3"><img src="/gfx/blank.gif" height="10" width="596" alt=""></td></tr>
			<tr>
				<td>&nbsp;&nbsp;</td>
				<td><p>Your [[SAFE::subject]] search results for <b>'[[SAFE::search_short]]'</b>:</p>
          	  <table width=550 align="center" ><tr><td><b>Transposon</b></td><td><b>Family</b></td>
			  <td><b>Submitter</b></td></tr>[[RAW::transposons]]</table>
          	  </td><td>&nbsp;&nbsp;</td></tr>
			<tr><td colspan="3"><img src="/gfx/blank.gif" height="10" width="596" alt=""></td></tr>
			</table>
		</td></tr>
	 <tr class="black" valign="top"><td><img src="/gfx/blank.gif" height="1" alt=""></td></tr>
        ),
		
	  'transposons'   => join( ' ', map( {
	   		$self->expand(
                qq(<tr><td valign="top" width="25%"><a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=transposon&db_id=[[URL::transposon_id]]&version=[[URL::version]]">[[SAFE::identifier]]</a></td>
						<td valign="top" width="30%">[[SAFE::family]] </td>
						<td valign="top">[[SAFE::submitter]]<br/> [[SAFE::org]]</td></tr>),
                   
				   'transposon_id' => $_->{transposon_id}, 
				   'identifier'  => $_->{identifier}, 
				   'version' => $_->{version}, 
				   'submitter' => $_->get_submitter()->first_name." ".$_->get_submitter()->name, 
				   'org' => "(".$_->get_submitter()->affiliation.")", 
				   'family' => $_->get_family()->name
            ) } @search
        ) ),
		
      'search_word'  => $self->parameter('search_word'),
	  'search_short' => substr($self->parameter('search_word'),0,15),
	  'subject'		 => $self->parameter('subject')
    );
  } 
}

sub ACTION_TransposonSearchForm{
    my $self = shift;
    my $transposon;
    my $error = $self->parameter('error');
    my $admin_search = "";
    my $start_year = 2001;
    my $years; 
    my ($year)  = (localtime)[5] ;
    	$year = $year + 1900;
        
    if ($self->user('is_admin')){
    $admin_search = qq(     
     <tr valign="top">
       <td class="gs_req" align="right" width="150">Version:</td>
	   <td class="gs_body"><input type="text" size="3" name="version" value="0" /></td>
     </tr>
     <tr valign="top">
       <td class="gs_req" align="right" width="150">Modified after:</td>
		<td class="gs_body">
		<table>
		  <tr>
		    <td><b>Day</b></td>
		    <td><b>Month</b></td>
		    <td><b>Year</b></td>
		  </tr><tr>	
		     <td class="gs_body"> [[DDOWN::nameday::1::days]] </td>
		     <td class="gs_body"> [[DDOWN::namemonth::1::months]] </td>
		     <td class="gs_body"> [[DDOWN::nameyear::2003::years]] </td>
      </tr></table></td>);
    }     

    $self->page( 'transposon/search.html',
       	
	'years'		=> join(':', $start_year..$year) ,
	'months'	=> join(':', 1..12 ),
	'days'		=> join(':', 1..31 ),
	'subjectlist'	=> 'Transposon:Submitter:Organisation:Family',
	'subjectname'	=> 'subject',
	'error'         => $error,
	'admin_search'	=> $admin_search,
	'nameday'	=> 'day',
	'nameyear'	=> 'year',
	'namemonth'	=> 'month',
    );
}

sub ACTION_unknownTransposon{
	my $self = shift;
	my $unkown = shift;
	$self->TABLE(
           qq(
<tr class="black" valign="top">
	<td rowspan="5"><img src="/gfx/blank.gif" height="1" alt=""></td>
	<td><img src="/gfx/blank.gif" height="1" alt=""></td>
	<td rowspan="5"><img src="/gfx/blank.gif" height="1" alt=""></td>
</tr>
<tr class="background2"><td class="h5">&nbsp;Unknown Transposon identifier</td></tr>
<tr class="black" valign="top"><td><img src="/gfx/blank.gif" height="1" alt=""></td></tr>
<tr>
	<td class="gs_body">
	<table align="center" border="0" cellpadding="0" cellspacing="0" width="596" >
    	<tr><td colspan="3"><img src="/gfx/blank.gif" height="10" width="596" alt=""></td></tr>
		<tr>
			<td>&nbsp;&nbsp;</td>
			<td><p><b>Could not find transposon <i>$unkown</i> in database.</b><br /><br /> Please check transposon_id</b><br/><br/></p>
            </td><td>&nbsp;&nbsp;</td></tr>
		<tr><td colspan="3"><img src="/gfx/blank.gif" height="10" width="596" alt=""></td></tr>
	</table>
</td></tr>
<tr class="black" valign="top"><td><img src="/gfx/blank.gif" height="1" alt=""></td></tr>))
}

1;
