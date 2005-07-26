package EnsEMBL::Web::GeneSubmission;

use Bio::EnsEMBL::Genename::DBSQL::GeneAdaptor;
use Bio::EnsEMBL::Genename::DBSQL::SubmitterAdaptor;
use Bio::EnsEMBL::Genename::DBSQL::SequenceAdaptor;
use Bio::EnsEMBL::Genename::DBSQL::XrefAdaptor;
use Bio::EnsEMBL::Genename::Gene;
use Bio::EnsEMBL::Genename::Submitter;
use Bio::EnsEMBL::Genename::Synonym;
use Bio::EnsEMBL::Genename::Sequence;
use Bio::EnsEMBL::Genename::Xref;

use Mail::Mailer;

use DBI;
use strict;
use EnsWeb;
use EnsEMBL::DB::Core;
use EnsEMBL::HTML::Page;
use CGI;

use constant GENESUB_SEQTYPES  => 'cDNA:protein' 	;
use constant GENESUB_STATI     => 'public:private'      ;
use constant GENESUB_XREFTYPES => 'SPTR:SPRO:EMBL:FlyBase:GenBank:Ensembl:Other' ;


##################################################################################################
## ADAPTOR FETCHING FUNCTIONS.................................................................. ##
## XrefAdaptor
## SequenceAdaptor
## GeneAdaptor
## SubmitterAdapator
## LiteAdaptor
##################################################################################################

sub XrefAdaptor {
    my $self = shift; 
    return $self->{'_xref_adaptor'} ||=
        Bio::EnsEMBL::Genename::DBSQL::XrefAdaptor->new($self->{'_submitter_dbh'});
}

sub TransposonSequenceAdaptor {
    my $self = shift; 
    return $self->{'_sequence_adaptor'}
        ||= Bio::EnsEMBL::Genename::DBSQL::SequenceAdaptor->new($self->{'_submitter_dbh'});
}

sub GeneAdaptor {
    my $self = shift; 
    return $self->{'_gene_adaptor'}
        ||= Bio::EnsEMBL::Genename::DBSQL::GeneAdaptor->new($self->{'_submitter_dbh'});
}

sub LiteAdaptor {
    my $databases = &EnsEMBL::DB::Core::get_databases('core','lite');
    my $self = shift; 
    return $databases->{'lite'}->get_GeneAdaptor();
}
                
##################################################################################################
## ACTION FUNCTIONS............................................................................ ##
## .._main
## .._register
## .._logout
## .._login
## .._mygenes
## .._allgenes
## .._addgene
## .._bulkadd
## .._updategene
## .._gene
## .._search
## .._search_form
##################################################################################################

sub ACTION_login {
    my $self = shift;
    if( $self->parameter('login') == 1 ) {
        ## ERROR CHECKING
        my $ID = $self->SubmitterAdaptor->get_user_id( $self->parameter('email'), $self->parameter('password') );
        if( $ID ) {
            $self->setCookie( $ID );
            $self->redirect( $self->parameter('task') eq 'login' ? '' : "action=".$self->parameter('task')  );
            return;
        }
    }
    
    $self->page( 'genesub/login.html',
        'email' => $self->parameter('email'),
        'action' => $self->parameter('action'),
    );
}

sub ACTION_mygenes { 
    my $self = shift;
    return $self->ACTION_login unless $self->user('submitter_id');
    
    if ($self->GeneAdaptor()->fetch_gene_by_submitter_id( $self->user('submitter_id') )){
        $self->TABLE(
	qq(
            <tr class="black" valign="top">
		<td rowspan="5"><img src="/gfx/blank.gif" height="1" alt=""></td>
		<td><img src="/gfx/blank.gif" height="1" alt=""></td>
		<td rowspan="5"><img src="/gfx/blank.gif" height="1" alt=""></td>
	</tr>
	<tr class="background2"><td class="h5">&nbsp;My Genenames</td></tr>
	<tr class="black" valign="top"><td><img src="/gfx/blank.gif" height="1" alt=""></td></tr>
	<tr>
		<td class="gs_body">
			<table align="center" border="0" cellpadding="0" cellspacing="0" width="596" >
    		<tr><td colspan="3"><img src="/gfx/blank.gif" height="10" width="596" alt=""></td></tr>
			<tr>
				<td>&nbsp;&nbsp;</td>
				<td><p>You have submitted the following gene names:</p>
                <table width="500" align="center"><tr>[[COLM::num::genes]]</tr></table>
            </td>
			<td>&nbsp;&nbsp;</td></tr>
				<tr><td colspan="3"><img src="/gfx/blank.gif" height="10" width="596" alt=""></td></tr>
					</table>
			</td></tr>
	<tr class="black" valign="top"><td><img src="/gfx/blank.gif" height="1" alt=""></td></tr>
        ),
	    'num' => 4,
	    'genes' => join( '<tr>', map( {
            $self->expand(
                qq(<td><a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=gene&db_id=[[URL::gene_id]]">[[SAFE::symbol]]</a></td>),
                'gene_id' => $_->gene_id, 'symbol'  => $_->symbol
            ) } $self->GeneAdaptor()->fetch_gene_by_submitter_id( $self->user('submitter_id') )
        ) ),
    );}
    
    else {
    $self->TABLE(
         qq(
	 <tr class="black" valign="top">
		<td rowspan="5"><img src="/gfx/blank.gif" height="1" alt=""></td>
		<td><img src="/gfx/blank.gif" height="1" alt=""></td>
		<td rowspan="5"><img src="/gfx/blank.gif" height="1" alt=""></td>
	</tr>
	<tr class="background2"><td class="h5">&nbsp;My Genenames</td></tr>
	<tr class="black" valign="top"><td><img src="/gfx/blank.gif" height="1" alt=""></td></tr>
	<tr>
		<td class="gs_body">
			<table align="center" border="0" cellpadding="0" cellspacing="0" width="596" >
    		<tr><td colspan="3"><img src="/gfx/blank.gif" height="10" width="596" alt=""></td></tr>
			<tr>
				<td>&nbsp;&nbsp;</td>
				<td><p><strong>You currently have no gene entries in the database</strong></p>
	 <p>Please click <a href="[[SCRIPT]]?action=AddGene">here</a> to enter a new  gene.</p>
	 </td><td>&nbsp;&nbsp;</td></tr>
				<tr><td colspan="3"><img src="/gfx/blank.gif" height="10" width="596" alt=""></td></tr>
					</table>
			</td></tr>
	<tr class="black" valign="top"><td><img src="/gfx/blank.gif" height="1" alt=""></td></tr>
    ))}
    return;
}

sub ACTION_allgenes{ 
    my $self = shift;
    
    if ($self->user('is_admin')){
    $self->TABLE(
        qq(
            <tr class="black" valign="top">
		<td rowspan="5"><img src="/gfx/blank.gif" height="1" alt=""></td>
		<td><img src="/gfx/blank.gif" height="1" alt=""></td>
		<td rowspan="5"><img src="/gfx/blank.gif" height="1" alt=""></td>
	</tr>
	<tr class="background2"><td class="h5">&nbsp;Administrator View</td></tr>
	<tr class="black" valign="top"><td><img src="/gfx/blank.gif" height="1" alt=""></td></tr>
	<tr>
		<td class="gs_body">
			<table align="center" border="0" cellpadding="0" cellspacing="0" width="596" >
    		<tr><td colspan="3"><img src="/gfx/blank.gif" height="10" width="596" alt=""></td></tr>
			<tr>
				<td>&nbsp;&nbsp;</td>
				<td><p>All genes:</p>
                	<table width="500" align="center"><tr>[[COLM::num::genes]]</tr></table>
           		 </td><td>&nbsp;&nbsp;</td></tr>
				<tr><td colspan="3"><img src="/gfx/blank.gif" height="10" width="596" alt=""></td></tr>
					</table>
			</td></tr>
	<tr class="black" valign="top"><td><img src="/gfx/blank.gif" height="1" alt=""></td></tr>
        ),
	  'num' => 4,
	  'genes' => join( '<tr>', map( {
	  $self->expand(
                qq(<td><a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=gene&db_id=[[URL::gene_id]]">[[SAFE::symbol]]</a> -  [[SAFE::status]]</td>),
                'gene_id' => $_->gene_id, 'symbol'  => $_->symbol, 'status' => $_->status

          ) } $self->GeneAdaptor()->fetch_public_private_genes()
        ) ),
    );
    } 
    
    else  {
    $self->TABLE(
        qq(
            <tr class="black" valign="top">
		<td rowspan="5"><img src="/gfx/blank.gif" height="1" alt=""></td>
		<td><img src="/gfx/blank.gif" height="1" alt=""></td>
		<td rowspan="5"><img src="/gfx/blank.gif" height="1" alt=""></td>
	</tr>
	<tr class="background2"><td class="h5">&nbsp;All Submitted Genes</td></tr>
	<tr class="black" valign="top"><td><img src="/gfx/blank.gif" height="1" alt=""></td></tr>
	<tr>
		<td class="gs_body">
			<table align="center" border="0" cellpadding="0" cellspacing="0" width="596" >
    		<tr><td colspan="3"><img src="/gfx/blank.gif" height="10" width="596" alt=""></td></tr>
			<tr>
				<td>&nbsp;&nbsp;</td>
				<td><p>All genes:</p>
                	<table width="500" align="center"><tr>[[COLM::num::genes]]</tr></table>
           		 </td><td>&nbsp;&nbsp;</td></tr>
				<tr><td colspan="3"><img src="/gfx/blank.gif" height="10" width="596" alt=""></td></tr>
					</table>
			</td></tr>
	<tr class="black" valign="top"><td><img src="/gfx/blank.gif" height="1" alt=""></td></tr>
        ),
	    'num' => 4,
	    'genes' => join( '<tr>', map( {
            $self->expand(
                qq(<td><a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=gene&db_id=[[URL::gene_id]]">[[SAFE::symbol]]</a></td>),
                'gene_id' => $_->gene_id, 'symbol'  => $_->symbol
            ) } $self->GeneAdaptor()->fetch_public_private_genes('public')
        ) ),
    );}
    return;
}

sub ACTION_deleteGene { 
    my $self = shift;
    my $gene = $self->GeneAdaptor()->fetch_gene_by_db_id( $self->parameter('db_id') );
        
    if (!$self->user('is_admin')){
       return $self->ACTION_gene() if $gene->get_submitter && $gene->get_submitter->submitter_id != $self->user('submitter_id');}
    
    if ($self->parameter('del')){
		$self->GeneAdaptor()->remove($gene); 
		$self->gene_EMAIL($gene, 'delete');
		if ($self->user('is_admin')){ return $self->ACTION_allgenes(); }
    		else { return $self->ACTION_mygenes(); } 
    }
        	
    $self->page( 'genesub/delete.html',
        'path'		=> $self->{'_constants'}{'GFX_BUTTONS'} ,
	'gene_id'       => $gene->gene_id,
        'symbol'        => $gene->symbol,
        'description'   => $gene->description,						
    );
}

sub ACTION_gene {
    my $self = shift;
    my $db_id = $self->parameter('db_id'); 
    my $symbol = $self->parameter('symbol');
    my $gene;
    my $ensembl_geneview_link = '';
    my $ensembl_location = '';
    my $lite_gene;
       if ($db_id) { $gene = $self->GeneAdaptor()->fetch_gene_by_db_id( $db_id,  $self->parameter('version') );}
       if ($symbol) { $gene = $self->GeneAdaptor()->fetch_gene_by_symbol( $symbol,  $self->parameter('version') );}
       return $self->ACTION_unknownGene($symbol) unless ($gene);
    
    my ($editing, $addsyn, $addseq, $addxref, $xref_head) = '';
    my $error;
    my $submitter_email ;

    $symbol = $gene->symbol;
    eval{ $lite_gene = $self->LiteAdaptor()->fetch_by_DBEntry('core', $symbol,1);   };
    
# print link to Geneview    
    if($lite_gene && !$@){
    	$ensembl_geneview_link = qq([<a
	href="/$ENV{'ENSEMBL_SPECIES'}/geneview?gene=$lite_gene->{_stable_id}">View in Geneview</a>]);
	$ensembl_location = sprintf qq(
	<tr valign="top">
         <td class="gs_req" align="right">Genomic location:</td>
         <td class="gs_body"> <b>Chr</b> %s: %s - %s <b>bp</b> (Strand %s)</td>
	 <td>&nbsp;</td>
        </tr>), $lite_gene->chr_name , $lite_gene->start , $lite_gene->end , $lite_gene->strand ; 
	} 

#	non-critical error messages    
    if ($self->parameter('message') =~ /orf/g){
	$error .= "<b>NOTICE:</b> Sequence has reading frame < 50 aa, but HAS been added to the database.<br/>";}
#	if owner of gene or admin, add edit links				            
    if ($self->user('is_admin') || $gene->get_submitter->submitter_id == $self->user('submitter_id')){
	$editing = qq(
	<br/><br/><table align="right">
	<tr>
	 <td>
	  <a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=UpdateGene&db_id=$gene->{gene_id}"><img src="$self->{'_constants'}{'GFX_BUTTONS'}/edit.gif" border='0' alt="Edit"></a>
	 </td>
	 <td>
	  <a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=deleteGene&db_id=$gene->{gene_id}"> <img src="$self->{'_constants'}{'GFX_BUTTONS'}/delete.gif" border='0' alt="Delete"></a>
	 </td> 
        </tr>
	</table>);

    	$addxref = qq(<td valign="middle">
			<a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=UpdateGene&addxref=1&db_id=$gene->{gene_id}">
			<img src="$self->{'_constants'}{'GFX_BUTTONS'}/add_xref.gif" border='0' alt="Add X-ref"> </a>
		      </td>);
	$addsyn = qq(<td valign="middle">
		   	  <a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=UpdateGene&addsyn=1&db_id=$gene->{gene_id}">
			  <img src="$self->{'_constants'}{'GFX_BUTTONS'}/add_syn.gif" border='0' alt="Add Synonym"> </a>
		     </td>);
	$addseq = qq(<td valign="top">
			<a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=UpdateGene&addseq=1&db_id=$gene->{gene_id}">
			<img src="$self->{'_constants'}{'GFX_BUTTONS'}/add_seq.gif" border='0' alt="Add Sequence">  </a>
		     </td>);
    }

#	if  admin show submitter e-mail				            
    if ($self->user('is_admin')){
    $submitter_email = $gene->get_submitter->email;
    }
     
     if ($gene->get_all_xref()){			# Hide headers if no XRef defined
     	  $xref_head = qq(<tr valign="top">
            <th class="gs_body">Database:</th>
            <th class="gs_body">Accession:</th>
          </tr>);}   	
	  	
    $self->page( 'genesub/gene.html',
    	'name'          => ($gene->get_submitter->first_name)." ".($gene->get_submitter->name),
        'affiliation'   => $gene->get_submitter->affiliation,
        'symbol'        => $symbol,
        'description'   => $gene->description,
        'version'       => $gene->version,
        'status'	=> $gene->status,
	'error'		=> $error,
	'xrefs'         => join( '', map( {
            $self->expand(
                '<tr valign="top" align="center"><td class="gs_body">[[SAFE::db]]</td><td class="gs_body">[[SAFE::accession]]</td>',
                'db' => $_->external_db, 'accession' => $_->dbprimary_id
            ) } $gene->get_all_xref()
        ) ),
        'synonyms'      => join( '', map( {
            $self->expand(
                '<li>[[SAFE::synonym]]</li>',
                'synonym' => $_->synonym
            ) } $gene->get_all_synonym()
        ) ),
        'sequences'      => join( '', map( {
            $self->expand(
                '<dl><dt><b>[[SAFE::type]]</b>: [[SAFE::ref]]</dt>'.
                '<pre>[[RAW::sequence]]</pre></dd></dl>',
                'type' => $_->sequence_type,
                'ref' => $_->sequence_ref,
                'sequence' => uc($self->chunked($_->sequence,40)),
            ) } $gene->get_all_sequence()
        ) ),
	'editing'	=> $editing,
	'addxref'	=> $addxref, 
	'addsyn'	=> $addsyn,
	'addseq'	=> $addseq,
	'ref_header'	=> $xref_head,
	'submitter_email' => $submitter_email,
	'geneview' 	=> $ensembl_geneview_link,
	'location'	=> $ensembl_location,
	 );
}

sub gene_EMAIL {
    my $self = shift;
    my $gene = shift;
    my $call = shift;
    my $old_gene;
    my $admin_modification = '';
    my $mailer = new Mail::Mailer 'smtp', Server => "mail.sanger.ac.uk";
    
    ### Find gene information for previous gene to build UPDATE E-mail
	my $gene_id = $gene->gene_id;

	$old_gene = $self->GeneAdaptor->fetch_gene_by_db_id($gene_id, $self->GeneAdaptor->get_max_version($gene_id));

    if ($self->user('is_admin')){$admin_modification = "by ". $self->user('fullname')."(administrator)"};
	
    my ($message, $subject, $modification) = '';
    if($call eq 'add'){
    $message = qq(\nThank you for submitting to EnsEMBL, we confirm the following Anopheles gene submission: \n );
    $subject = "Gene Submission: ";
    }
    if($call eq 'delete'){
    $message = qq(\nThe following gene has been deleted from the Anopheles EnsEMBL database $admin_modification : \n);
    $subject = "Gene Deletion: ";
    }
    if($call eq 'update'){
    $message = qq(\nThe gene [[SAFE::old_symbol]] in the Anopheles EnsEMBL database has been modified $admin_modification to: \n);
    $subject = "Gene Modification: ";
    
    }
    
    $mailer->open({
            'To'        => $self->{'_constants'}{'SUBMISSION_EMAIL'},
	    'Cc' 	=> $gene->get_submitter->email, 
            'Subject'   => "$subject".$gene->symbol." (".$gene->gene_id.")",
    });
    print $mailer $self->expand(qq(
Dear [[SAFE::name]],
$message

Submitter:        	[[SAFE::name]] ([[SAFE::affiliation]])
Proposed symbol:  	[[SAFE::symbol]]
Description:      	[[SAFE::description]]
Status:           	[[SAFE::status]]

Xrefs:
[[RAW::xrefs]]
Synonyms:
[[RAW::synonyms]]
Sequence:
[[RAW::sequences]]
$modification
Kind regards,

EnsEMBL Development Team.
        ),
        'name'          => ($gene->get_submitter->first_name)." ".($gene->get_submitter->name),
        'affiliation'   => $gene->get_submitter->affiliation,
        'symbol'        => $gene->symbol,
        'status'        => $gene->status,
        'description'   => $gene->description,
        'xrefs'         => join( '', map( {
            $self->expand(
                "    [[SAFE::db]]   [[SAFE::accession]]\n",
                'db' => $_->external_db, 'accession' => $_->dbprimary_id
            ) } $gene->get_all_xref()
        ) ),
        'synonyms'      => join( '', map( {
            $self->expand(
                "    [[SAFE::synonym]]\n",
                'synonym' => $_->synonym
            ) } $gene->get_all_synonym()
        ) ),
        'sequences'      => join( '', map( {
            $self->expand(
                "\n[[SAFE::type]]: [[SAFE::ref]]\n".
                          "[[RAW::sequence]]\n",
                'type' => $_->sequence_type,
                'ref' => $_->sequence_ref,
                'sequence' => $self->chunked($_->sequence,60,"\n"),
            ) } $gene->get_all_sequence()
        ) ),
		'old_symbol'        => $old_gene->symbol,
    );
    $mailer->close;
}

sub ACTION_UpdateGene{
    my $self = shift;
    my $warning = '';
    my $message ; 
    my $success = 0;
    my $gene;
    my $seq_no_ws;
    my ($AddXref, $AddSyn, $AddSeq) = '';
         
    $AddXref = qq(
    	<tr valign="top">
            <td class="gs_body">[[DDOWN::dbname::db_0::dbs]]</td>
            <td class="gs_body"><input type="text" size="15" name="ac_0" value="[[SAFE::ac]]" ></td>
    	</tr>) if  ( $self->parameter( 'addxref' ));
       
    $AddSyn = qq(<li><input type="text" size="15" name="synonym_0" value="[[SAFE::synonym_0]]" ></li>) if  ( $self->parameter( 'addsyn' ));
      
    $AddSeq = qq(
            <tr><td><strong>Type:</strong></td><td colspan="3"><strong>Name</strong></td></tr>
            <tr><td>[[DDOWN::typename::type_0::types]]</td><td colspan="3"><input name="ref_0" value="[[SAFE::ref_0]]" size="15" /></td></tr>
            <tr><td colspan="4"><textarea cols="40" rows="8" name="sequence_0">[[RAW::sequence_0]]</textarea></td></tr>) if  ( $self->parameter( 'addseq' ));
    
    return $self->ACTION_login unless $self->user('submitter_id');
    
    eval {$gene = $self->GeneAdaptor()->fetch_gene_by_db_id( $self->parameter( 'db_id' ) );};
     
    if( $gene ) {
       if (!$self->user('is_admin')){
       return $self->ACTION_gene() if $gene->get_submitter && $gene->get_submitter->submitter_id != $self->user('submitter_id');} 
    }
    else {return $self->ACTION_AddGene();}
        
    if ($self->parameter('update') == 1){			
	$gene->symbol(      $self->parameter('symbol') );
        $gene->status(      $self->parameter('status') );
        $gene->description( $self->parameter('description') );	
# Xrefs        
        foreach my $xref ( $gene->get_all_xref() ) {
            $xref->dbprimary_id( $self->parameter( 'ac_'.$xref->xref_id ) );
            $xref->external_db( $self->parameter( 'db_'.$xref->xref_id ) );
        }
# Xrefs (addxref)
          if( $self->parameter('db_0') && $self->parameter('ac_0') && 
            $self->parameter('db_0') ne '' && $self->parameter('ac_0') ne '') {
            $gene->add_xref(
                Bio::EnsEMBL::Genename::Xref->new( 
                    -adaptor => $self->XrefAdaptor(),
                    -dbprimary_id => $self->parameter('ac_0' ),
                    -external_db  => $self->parameter('db_0' ),
                ));   
        }
# Synonyms 
        foreach my $synonym ( $gene->get_all_synonym() ) {
            $synonym->synonym( $self->parameter( 'synonym_'.$synonym->synonym_id ) );
	}
# Synonyms (addsyn)
	if( $self->parameter('synonym_0') && $self->parameter('synonym_0') ne '' ) {
            $gene->add_synonym(
                Bio::EnsEMBL::Genename::Synonym->new( 
                    -synonym  => $self->parameter('synonym_0' )
                ));   
        }	
# Sequences       
	foreach my $sequence ( $gene->get_all_sequence() ) {
            ($seq_no_ws = $self->parameter('sequence_'.$sequence->sequence_id )) =~ s/\s+//g;  
	    $sequence->sequence($seq_no_ws);
	    $sequence->sequence_ref(  $self->parameter( 'ref_'.$sequence->sequence_id ) );
            $sequence->sequence_type( $self->parameter( 'type_'.$sequence->sequence_id ) );
	}
#Sequences(addseq)      				 
	if( $self->parameter('sequence_0') && $self->parameter('sequence_0') ne '') {
	($seq_no_ws = $self->parameter('sequence_0')) =~ s/\s+//g; 
	    $gene->add_sequence(
	     Bio::EnsEMBL::Genename::Sequence->new( 
                -adaptor  => $self->TransposonSequenceAdaptor(),
                -sequence  => $seq_no_ws,
                -sequence_ref  => $self->parameter('ref_0' ),
                -sequence_type  => $self->parameter('type_0' ),
            ));
	}
	if($gene->gene_id) {
            if ($success = $gene->update()){
                   # Check ORF
		my @sequence = $gene->get_all_sequence;
		for my $sequence (@sequence){
		 if ($sequence->sequence_type eq 'cDNA'){
		   $message = "orf-" if (length($sequence->get_longest_orf()) < 50);}}
		 print "Location: /$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=gene&db_id=".$gene->gene_id."&message=".$message ;
		 $self->gene_EMAIL($gene, 'update');
                return;
	    }
            else {
	     	if ($self->TransposonSequenceAdaptor->err()){ $warning = "<b>WARNING: </b>". join ("<br/>",$self->TransposonSequenceAdaptor->err()) ;}
		if ($self->GeneAdaptor->err()){ $warning = "<b>WARNING: </b>". join ("<br/>",$self->GeneAdaptor->err());}
	    }
        } 
}
#if not update make everything read only except the 'add' item
my ($ro_symbol, $ro_status, $ro_desc, $ro_xref, $ro_syn, $ro_seq) = '';
if ($AddXref || $AddSeq || $AddSyn){
  $ro_symbol = qq([[SAFE::symbol]]\n<input type="hidden" name="symbol" value="[[SAFE::symbol]]">\n);
  $ro_status = qq([[SAFE::status]]\n<input type="hidden" name="status" value="[[SAFE::status]]">\n);
  $ro_desc = qq([[SAFE::description]]\n<input type="hidden" name="description" value="[[SAFE::description]]">\n);
  $ro_xref = qq([[RAW::ro_xrefs]]);
  $ro_syn = qq([[RAW::ro_synonyms]]);
  $ro_seq = qq([[RAW::ro_sequences]]);
}
else{
  $ro_symbol = '<input type="text" name="symbol" size="40" value="[[SAFE::symbol]]">';
  $ro_status = '[[DDOWN::statusname::status::stati]]';
  $ro_desc = '<textarea name="description" rows="5" cols="40">[[SAFE::description]]</textarea>';
  $ro_xref = qq([[RAW::xrefs]]);
  $ro_syn = qq([[RAW::synonyms]]);
  $ro_seq = qq([[RAW::sequences]]);
}
    $self->TABLE(
        qq( <form action="[[SCRIPT]]" method="post">
  <input type="hidden" name="action" value="UpdateGene">
  <input type="hidden" name="update" value="1">
  <input type="hidden" name="db_id" value="[[SAFE::gene_id]]">
  
  <tr class="black" valign="top">
	<td rowspan="5"><img src="/gfx/blank.gif" height="1" alt=""></td>
	<td><img src="/gfx/blank.gif" height="1" alt=""></td>
	<td rowspan="5"><img src="/gfx/blank.gif" height="1" alt=""></td>
</tr>
<tr class="background2"><td class="h5">&nbsp;Edit Gene</td></tr>
<tr class="black" valign="top"><td><img src="/gfx/blank.gif" height="1" alt=""></td></tr>
<tr>
	<td class="gs_body">
	<table align="center" border="0" cellpadding="0" cellspacing="0" width="596" >
    	<tr><td colspan="3"><img src="/gfx/blank.gif" height="10" width="596" alt=""></td></tr>
		<tr>
			<td>&nbsp;&nbsp;</td>
			<td><p>
Edit the required gene details and click <b>Update</b>.<br />
  </p>
    <p class="gs_req">[[RAW::error]]</p>
    <table border="0" cellspacing="0" cellpadding="2">
    <tr valign="top">
      <td class="gs_req" align="right" width="150">Submitter:</td>
      <td class="gs_body" width="442">[[SAFE::name]] ([[SAFE::affiliation]])</td>
    </tr>
    <tr valign="top">
      <td class="gs_req" align="right" width="150">Proposed symbol:</td>
      <td class="gs_body" width="442">$ro_symbol</td>
    </tr>
    <tr valign="top">
      <td class="gs_req" align="right" width="150">Status:</td>
      <td class="gs_body" width="442">$ro_status</td>
    </tr>
    <tr valign="top">
      <td class="gs_req" align="right">Description:</td>
      <td class="gs_body">$ro_desc</td>
    </tr>
    <tr valign="top">
      <td class="gs_req" align="right">Cross-reference:</td>
      <td class="gs_body">
        <table border="0" cellspacing="0" cellpadding="2">
          <tr valign="top">
            <th class="gs_body">Database:</th>
            <th class="gs_body">Accession:</th>
          </tr>
          $ro_xref          
	  $AddXref        
	</table>
      </td>
    </tr>
    <tr valign="top">
      <td class="gs_req" align="right">Synonyms:</td>
      <td class="gs_body">
		<ul>
		$ro_syn  
		$AddSyn
		</ul>
	</td>
    </tr>
    <tr valign="top">
      <td class="gs_req" align="right">Sequence:</td>
      <td class="gs_body">
          <table border="0" cellspacing="0" cellpadding="2">
           $ro_seq            
           $AddSeq 	    
          </table>
      </td>
    </tr>
    <tr valign="top">
      <td colspan="2" align="center" class="gs_req" align="right"><input type="submit" value="Update"></td>
    </tr>
    </table>
    </td><td>&nbsp;&nbsp;</td></tr>
		<tr><td colspan="3"><img src="/gfx/blank.gif" height="10" width="596" alt=""></td></tr>
	</table>
</td></tr>
<tr class="black" valign="top"><td><img src="/gfx/blank.gif" height="1" alt=""></td></tr>

  </form>       ),
        'name'          => $self->user( 'fullname' ),
        'affiliation'   => $self->user( 'affiliation' ),
        'gene_id'       => $gene->gene_id,
        'symbol'        => $gene->symbol,
        'description'   => $gene->description,
        'version'       => $gene->version,
        'xrefs'         => join( '', map( {
            $self->expand(
                '<tr valign="top"><td class="gs_body" align="center">[[DDOWN::dbname::db::dbs]]</td>
                                  <td class="gs_body" align="center"><input name="[[SAFE::acname]]" value="[[SAFE::ac]]" size="15" /></td>',
                'dbname'=> 'db_'.($_->xref_id||'0'),
                'acname'=> 'ac_'.($_->xref_id||'0'),
                'db'    => $_->external_db,
                'ac'    => $_->dbprimary_id,
                'dbs'   => GENESUB_XREFTYPES
            ) } $gene->get_all_xref
        ) ),
		'ro_xrefs'         => join( '', map( {
            $self->expand(
                '<tr valign="top"><td class="gs_body" align="center">[[SAFE::db]]<input type="hidden" name="[[SAFE::dbname]]" value="[[SAFE::db]]"></td>
                                  <td class="gs_body" align="center">[[SAFE::ac]]<input type="hidden" name="[[SAFE::acname]]" value="[[SAFE::ac]]"></td>',
                'dbname'=> 'db_'.($_->xref_id||'0'),
                'acname'=> 'ac_'.($_->xref_id||'0'),
                'db'    => $_->external_db,
                'ac'    => $_->dbprimary_id,
                'dbs'   => GENESUB_XREFTYPES
            ) } $gene->get_all_xref
        ) ),
        'synonyms'      => join( '', map( {
            $self->expand(
                '<input name="[[SAFE::synonymname]]" value="[[SAFE::synonym]]" size="15" /><br />',
                'synonymname' => 'synonym_'.($_->synonym_id||'0'),
                'synonym' => $_->synonym
            ) } $gene->get_all_synonym
        ) ),
		'ro_synonyms'      => join( '', map( {
            $self->expand(
                '<li>[[SAFE::synonym]]</li><input type="hidden" name="[[SAFE::synonymname]]" value="[[SAFE::synonym]]">',
                'synonymname' => 'synonym_'.($_->synonym_id||'0'),
                'synonym' => $_->synonym
            ) } $gene->get_all_synonym
        ) ),
        'sequences'      => join( '', map( {
            $self->expand(
            '<tr><td><strong>Type:</strong></td><td colspan="3"><strong>Name</strong></td></tr>
            <tr><td>[[DDOWN::typename::type::types]]</td><td colspan="3"><input name="ref_[[SAFE::id]]" value="[[SAFE::ref]]" size="15" /></td></tr>
            <tr><td colspan="4"><textarea cols="40" rows="8" name="sequence_[[SAFE::id]]">[[RAW::sequence]]</textarea></td></tr>',
                'typename'    => 'type_'.($_->sequence_id||'0'),
                'type'        => $_->sequence_type,
                'refname'     => 'ref_'.($_->sequence_id||'0'),
		'ref'         => ($_->sequence_ref||'0'),
                'types'       => GENESUB_SEQTYPES,
                'id'          => ($_->sequence_id||'0'),
                'sequence'    => $self->chunked($_->sequence,40,"\n"),
             ) } $gene->get_all_sequence()
        ) ),
		'ro_sequences'      => join( '', map( {
            $self->expand(
            '<tr><td width="120"><strong>Type:</strong> [[SAFE::type]] </td><td colspan="3"><strong>Name:</strong> [[SAFE::ref]]</td></tr>
            <input type="hidden" name="[[SAFE::typename]]" value="[[SAFE::type]]">
	    <input type="hidden" name="ref_[[SAFE::id]]" value="[[SAFE::ref]]"> 
            <tr><td colspan="4"><p><pre>[[RAW::sequence]] </pre>
	    <input type="hidden" name="sequence_[[SAFE::id]]" value="[[RAW::sequence]]"></td></tr>',
                'typename'    => 'type_'.($_->sequence_id||'0'),
                'type'        => $_->sequence_type,
                'refname'     => 'ref_'.($_->sequence_id||'0'),
		'ref'         => ($_->sequence_ref||'0'),
                'types'       => GENESUB_SEQTYPES,
                'id'          => ($_->sequence_id||'0'),
                'sequence'    => $self->chunked($_->sequence,40,"\n"),
             ) } $gene->get_all_sequence()
        ) ),
        'statusname'    => 'status',
        'status'        => $gene->status,
        'stati'         => GENESUB_STATI,
        'dbname'        => 'db_0',
        'db_0'          => $self->parameter('db_0'),
        'synonym_0'     => $self->parameter('synonym_0'),
        'ac_0'          => $self->parameter('ac_0'),
        'dbs'           => GENESUB_XREFTYPES,
        'typename'      => 'type_0',
        'type_0'        => $self->parameter('type_0'),
        'types'         => GENESUB_SEQTYPES,
	'sequence_0'    => uc($seq_no_ws),
        'error'         => $warning,	
    );
}

sub ACTION_AddGene{
    my $self = shift;
    my $success = 1; 
    my $warning;            
    my $gene;
    my $seq_no_ws;
    my $message = '';
    
    return $self->ACTION_login unless $self->user('submitter_id'); # pass to login if no user 
    
    $gene = Bio::EnsEMBL::Genename::Gene->new(                  #create new gene object
        -adaptor        =>  $self->GeneAdaptor(),                   
        -submitter_id   =>  $self->user('submitter_id'),
        -description    =>  $self->parameter('description'),
        -symbol         =>  $self->parameter('symbol'),
        -status         =>  $self->parameter('status'),
    );

  if ($self->parameter('submitted')==1){
# Xref    
    if( $self->parameter('db_0') && $self->parameter('ac_0') && 
        $self->parameter('db_0') ne '' && $self->parameter('ac_0') ne '') {
            ## Add check for database accession number check (format...regex)
            $gene->add_xref(
                Bio::EnsEMBL::Genename::Xref->new( 
                    -adaptor        => $self->XrefAdaptor(),
                    -dbprimary_id   => $self->parameter('ac_0' ),
                    -external_db    => $self->parameter('db_0' ),
                ));   
     }        
# Synonyms
        if( $self->parameter('synonym_0') && $self->parameter('synonym_0') ne '') {
            $gene->add_synonym(
                Bio::EnsEMBL::Genename::Synonym->new( 
                    -synonym  => $self->parameter('synonym_0' )
                ));   
        }       
# Sequences 
        ($seq_no_ws = $self->parameter('sequence_0')) =~ s/\s+//g;  
	if( $self->parameter('sequence_0') && $self->parameter('sequence_0') ne '' ) {
	    $gene->add_sequence(
                Bio::EnsEMBL::Genename::Sequence->new( 
                    -adaptor        => $self->TransposonSequenceAdaptor(),
                    -sequence       => $seq_no_ws,
                    -sequence_ref   => $self->parameter('ref_0' ) || $self->parameter('symbol'),
                    -sequence_type  => $self->parameter('type_0' ),
                ));
        }
	      
	    $success = $gene->store();         
            if($success){  
#check orf
		my @sequence = $gene->get_all_sequence;
		for my $sequence (@sequence){
		if ($sequence->sequence_type eq 'cDNA'){
		$message = "orf-" if (length($sequence->get_longest_orf()) < 50);}}

		print "Location: /$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=gene&db_id=".$gene->gene_id."&message=".$message ;
		$self->gene_EMAIL($gene, 'add');
		return;
             }
	     else {
	     	if ($self->TransposonSequenceAdaptor->err()){ $warning = "<b>WARNING:</b><br/> ". join ("<br/> ",$self->TransposonSequenceAdaptor->err()) ;}
		if ($self->GeneAdaptor->err()){ $warning = "<b>WARNING</b><br/> ". join ("<br/> ",$self->GeneAdaptor->err());}
	     }	 
	$gene->gene_id(0);
  }
    
    $self->page( 'genesub/add.html',    
        'error'         => $warning,
        'name'          => $self->user( 'fullname' ),
        'affiliation'   => $self->user( 'affiliation' ),
        'gene_id'       => $gene->gene_id,
        'symbol'        => $gene->symbol,
        'description'   => $gene->description,
        'version'       => $gene->version,
        'statusname'    => 'status',
        'status'        => $gene->status,
        'stati'         => GENESUB_STATI,
        'dbname'        => 'db_0',
        'db_0'          => $self->parameter('db_0'),
        'synonym_0'     => $self->parameter('synonym_0'),
        'ac_0'          => $self->parameter('ac_0'),
        'dbs'           => GENESUB_XREFTYPES,
        'typename'      => 'type_0',
        'type_0'        => $self->parameter('type_0'),
        'types'         => GENESUB_SEQTYPES,
        'ref_0'		=> $self->parameter('ref_0'),
	'sequence_0'    => uc($seq_no_ws),
    );
}

sub ACTION_bulkaddGene{
    my $self = shift;
    my $error = 0;
    my $warning = "";
    my $found_header = 0;
    my $file = CGI::param('gene_file') ;
    my %genes;
    my $gene;
    
    return $self->ACTION_login unless $self->user('submitter_id'); # pass to login if no user 

    if ($self->parameter('upload') && $self->parameter('gene_file')){    	
	%genes = $self->GeneAdaptor->Parse_FastA($file);
	
    for my $gene_symbol (keys %genes){
    $gene = Bio::EnsEMBL::Genename::Gene->new(                 
        -adaptor        =>  $self->GeneAdaptor(),                   
        -submitter_id   =>  $self->user('submitter_id'),
        -description    =>  $genes{$gene_symbol}{'description'}[0],
        -symbol         =>  $gene_symbol,
        -status         =>  $self->parameter('status'),
    );
    	for my $gene_data (@{$genes{$gene_symbol}{'xref'}}){
	my ($ex_db, $db_id) = split /:/, $gene_data;
	$gene->add_xref(
                Bio::EnsEMBL::Genename::Xref->new( 
                    -adaptor        => $self->XrefAdaptor(),
                    -dbprimary_id   => $db_id,
                    -external_db    => $ex_db,
                )
        ); 
    	}
	for my $gene_data (@{$genes{$gene_symbol}{'synonym'}}){
	$gene->add_synonym(
                Bio::EnsEMBL::Genename::Synonym->new( 
                    -synonym  => $gene_data,
                )
        );   
    	}
	for my $sequence_data (@{$genes{$gene_symbol}{'sequence'}}){
	my ($sequence_name, $sequence) = split /:/ , $sequence_data ;
	$sequence_name = $gene_symbol unless $sequence_name;
	my $sequence_type = Bio::EnsEMBL::Genename::Sequence->dna_protein($sequence);
	
	$gene->add_sequence(
                Bio::EnsEMBL::Genename::Sequence->new( 
                    -adaptor        => $self->TransposonSequenceAdaptor(),
                    -sequence       => $sequence,
                    -sequence_ref   => $sequence_name,
                    -sequence_type  => $sequence_type,
                )
            );
    	}
    my $success = $gene->store();
    if (!$success){
    $warning .= "<b>Gene $gene_symbol not added to database:</b><br>";
    $warning .= join ("<br> ",$self->GeneAdaptor->err()) ."<p class='gs_req'>" if $self->GeneAdaptor->err();
    $warning .= join ("<br> ",$self->TransposonSequenceAdaptor->err()) ."<p class='gs_req'>" if $self->TransposonSequenceAdaptor->err();}
    $self->GeneAdaptor->flush_err();
    $self->TransposonSequenceAdaptor->flush_err();
    }  	
	if ($warning){$error = 1;}
    	else{print "Location: /$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=mygenes";}
    }
    if ($self->parameter('upload') && !$self->parameter('gene_file')){
    	$warning = "Please enter a file name to upload";
    }
   if (!$error){	
    
   $self->page( 'genesub/bulk_submit.html', 
	'stati'		=> 'public:private',
	'error'         => $warning,
    	'statusname'    => 'status',
    );
}
else {
	$self->TABLE(
		qq(<tr><td class="background2">Bulk Gene Submission</td></tr>
  	<tr><td class="gs_body">
      <p>Your file contained errors:
      <p class="gs_req">[[RAW::error]]</p>
      </td>
     </tr>
     <tr valign="top">
      <td colspan="2" align="center" class="gs_req" align="right"><br/><a href="[[SCRIPT]]?action=mygenes">View Genes</a></td>
     </tr>
    </table>
    </td></tr>
	),
	'error'         => $warning,
    	);
      }
}

sub ACTION_GeneSearch{
	my $self = shift;
	my @genes = ();
	my $search_adaptor;
	my $status_search = 'public';
	
	if (!$self->parameter('search_word')){
		print "Location:/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=GeneSearchForm&error=No search term entered";
	}
	if ($self->user('is_admin')){$status_search = $self->parameter('status')}
		
	if ($self->parameter('subject') eq 'Gene symbol'){$search_adaptor = "fetch_gene_by_synonym_symbol";}
	elsif ($self->parameter('subject') eq 'X-reference'){$search_adaptor = "fetch_gene_by_xref";}
	elsif ($self->parameter('subject') eq 'Submitter'){$search_adaptor = "fetch_gene_by_submitter";}
	elsif ($self->parameter('subject') eq 'Organisation'){$search_adaptor = "fetch_gene_by_organisation";}
	elsif ($self->parameter('subject') eq 'Keyword'){$search_adaptor = "fetch_gene_by_keyword";}
	elsif ($self->parameter('subject') eq 'Sequence'){$search_adaptor = "fetch_gene_by_sequence";}
	else {return $self->ACTION_allgenes;}
	my $date = $self->parameter('year').'-'.$self->parameter('month').'-'.$self->parameter('day') ;
	my $submission_id = $self->GeneAdaptor()->get_submission_id_by_date($date);
	my @search = $self->GeneAdaptor()->$search_adaptor( $self->parameter('search_word'), $self->parameter('version'), $status_search, $submission_id);

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
	Click <a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=GeneSearchForm">here</a> to search again</p>
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
          	  <table width=550 align="center" ><tr><td><b>Gene name</b></td><td><b>Description</b></td><td ><b>Submitter</b></td></tr>[[RAW::genes]]</table>
          	  	</td><td>&nbsp;&nbsp;</td></tr>
				<tr><td colspan="3"><img src="/gfx/blank.gif" height="10" width="596" alt=""></td></tr>
			  </table>
		</td></tr>
	<tr class="black" valign="top"><td><img src="/gfx/blank.gif" height="1" alt=""></td></tr>
        ),
	  'genes'   => join( ' ', map( {
	   $self->expand(
                qq(<tr><td valign="top" width="15%"><a href="/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?action=gene&db_id=[[URL::gene_id]]&version=[[URL::version]]">[[SAFE::symbol]]</a></td><td
                   valign="top" width="35%">[[SAFE::desc]] </td><td valign="top">[[SAFE::submitter]]<br/> [[SAFE::org]]</td></tr>),
                   'gene_id' => $_->{gene_id}, 'symbol'  => $_->{symbol}, 'version' => $_->{version}, 'submitter' =>
                   $_->get_submitter()->first_name." ".$_->get_submitter()->name, 'org' => "(".$_->get_submitter()->affiliation.")", 'desc' => substr($_->{description},0,30)
            ) } @search
        ) ),
    	  'search_word' => $self->parameter('search_word'),
	  'search_short' => substr($self->parameter('search_word'),0,15),
	  'subject'	=> $self->parameter('subject')
    );
  } 
}

sub ACTION_GeneSearchForm{
    my $self = shift;
    my $gene;
    my $error = $self->parameter('error');
    my $admin_search = "";
    my $start_year = 2001;
    my $years; 
    my ($year)  = (localtime)[5] ;
    	$year = $year + 1900;
        
    if ($self->user('is_admin')){
    $admin_search = qq(
     <tr valign="top">
       <td class="gs_req" align="right" width="150">Status:</td>
       <td class="gs_body" width="442">[[DDOWN::statusname::status::all]]</td>
     </tr>
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
		     <td class="gs_body"> [[DDOWN::nameyear::2001::years]] </td>
                  </tr></table></td>);
    }     

    $self->page( 'genesub/search.html',
       	'all'		=> 'All:public:private',
	'years'		=> join(':', $start_year..$year) ,
	'months'	=> join(':', 1..12 ),
	'days'		=> join(':', 1..31 ),
	'subjectlist'	=> 'Gene symbol:X-reference:Submitter:Organisation:Keyword:Sequence',
	'subjectname'	=> 'subject',
	'error'         => $error,
        'statusname'    => 'status',
	'admin_search'	=> $admin_search,
	'nameday'	=> 'day',
	'nameyear'	=> 'year',
	'namemonth'	=> 'month',
    );
}

sub ACTION_unknownGene{
	my $self = shift;
	my $unkown = shift;
	$self->TABLE(
           qq(
            <tr class="black" valign="top">
	<td rowspan="5"><img src="/gfx/blank.gif" height="1" alt=""></td>
	<td><img src="/gfx/blank.gif" height="1" alt=""></td>
	<td rowspan="5"><img src="/gfx/blank.gif" height="1" alt=""></td>
</tr>
<tr class="background2"><td class="h5">&nbsp;Unknown Gene Symbol</td></tr>
<tr class="black" valign="top"><td><img src="/gfx/blank.gif" height="1" alt=""></td></tr>
<tr>
	<td class="gs_body">
	<table align="center" border="0" cellpadding="0" cellspacing="0" width="596" >
    	<tr><td colspan="3"><img src="/gfx/blank.gif" height="10" width="596" alt=""></td></tr>
		<tr>
			<td>&nbsp;&nbsp;</td>
			<td><p><b>Could not find gene symbol <i>$unkown</i> in database.</b><br /><br /> Please check gene symbol or gene_id</b><br/><br/></p>
            </td><td>&nbsp;&nbsp;</td></tr>
		<tr><td colspan="3"><img src="/gfx/blank.gif" height="10" width="596" alt=""></td></tr>
	</table>
</td></tr>
<tr class="black" valign="top"><td><img src="/gfx/blank.gif" height="1" alt=""></td></tr>))
}

1;
