#!/usr/bin/env python3
"""
Script to sync the knowledge base with the latest policy documents
"""
import boto3
import argparse
import logging
import time
import os
import sys

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def sync_knowledge_base(region, kb_id=None, kb_name=None, policy_bucket=None, wait=False):
    """Sync the knowledge base with the latest policy documents"""
    try:
        # Initialize clients
        bedrock = boto3.client('bedrock', region_name=region)
        ssm = boto3.client('ssm', region_name=region)
        
        # Get knowledge base ID if not provided
        if not kb_id:
            if kb_name:
                # Find by name
                response = bedrock.list_knowledge_bases()
                for kb in response.get('knowledgeBases', []):
                    if kb['name'] == kb_name:
                        kb_id = kb['knowledgeBaseId']
                        break
            else:
                # Get from SSM
                name_prefix = os.environ.get('NAME_PREFIX', 'pricing-agent-dev')
                response = ssm.get_parameter(Name=f"/{name_prefix}/knowledge-base-id")
                kb_id = response['Parameter']['Value']
        
        if not kb_id:
            logger.error("Knowledge base not found")
            return False
        
        # Get data source ID
        response = bedrock.list_data_sources(knowledgeBaseId=kb_id)
        data_source_id = None
        for ds in response.get('dataSources', []):
            if ds['name'] == 'pricing-policies':
                data_source_id = ds['dataSourceId']
                break
        
        if not data_source_id:
            logger.error("Data source not found")
            return False
        
        # Start data ingestion job
        response = bedrock.start_ingestion_job(
            knowledgeBaseId=kb_id,
            dataSourceId=data_source_id
        )
        
        ingestion_job_id = response['ingestionJob']['ingestionJobId']
        logger.info(f"Started ingestion job: {ingestion_job_id}")
        
        # Wait for job completion if requested
        if wait:
            logger.info("Waiting for ingestion job to complete...")
            status = "STARTING"
            while status in ["STARTING", "IN_PROGRESS"]:
                time.sleep(10)
                response = bedrock.get_ingestion_job(
                    knowledgeBaseId=kb_id,
                    dataSourceId=data_source_id,
                    ingestionJobId=ingestion_job_id
                )
                status = response['ingestionJob']['status']
                logger.info(f"Job status: {status}")
            
            if status == "COMPLETE":
                logger.info("Knowledge base sync completed successfully")
                return True
            else:
                logger.error(f"Knowledge base sync failed: {status}")
                return False
        
        return True
        
    except Exception as e:
        logger.error(f"Error syncing knowledge base: {str(e)}")
        return False

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Sync knowledge base with policy documents")
    parser.add_argument("--region", default="us-east-1", help="AWS region")
    parser.add_argument("--kb-id", help="Knowledge base ID (optional)")
    parser.add_argument("--kb-name", help="Knowledge base name (optional)")
    parser.add_argument("--wait", action="store_true", help="Wait for job completion")
    
    args = parser.parse_args()
    
    success = sync_knowledge_base(
        region=args.region,
        kb_id=args.kb_id,
        kb_name=args.kb_name,
        wait=args.wait
    )
    
    sys.exit(0 if success else 1)
