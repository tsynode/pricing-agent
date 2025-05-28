#!/usr/bin/env python3
"""
Simplified script to sync the knowledge base with the latest policy documents
"""
import boto3
import argparse
import logging
import time
import os
import sys

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def sync_knowledge_base(region, wait=False):
    """Sync the knowledge base with the latest policy documents"""
    try:
        # Initialize clients
        bedrock = boto3.client('bedrock', region_name=region)
        ssm = boto3.client('ssm', region_name=region)
        
        # Get knowledge base ID from SSM parameter
        name_prefix = os.environ.get('NAME_PREFIX', 'pricing-agent')
        logger.info(f"Using name prefix: {name_prefix}")
        
        # Get the knowledge base ID from SSM
        try:
            response = ssm.get_parameter(Name=f"/{name_prefix}/knowledge-base-id")
            kb_id = response['Parameter']['Value']
            logger.info(f"Found knowledge base ID: {kb_id}")
        except Exception as e:
            logger.error(f"Failed to get knowledge base ID from SSM: {str(e)}")
            return False
        
        # Get data source ID - hardcoded name for simplicity
        data_source_name = 'pricing-policies'
        logger.info(f"Looking for data source: {data_source_name}")
        
        response = bedrock.list_data_sources(knowledgeBaseId=kb_id)
        data_source_id = None
        for ds in response.get('dataSources', []):
            if ds['name'] == data_source_name:
                data_source_id = ds['dataSourceId']
                logger.info(f"Found data source ID: {data_source_id}")
                break
        
        if not data_source_id:
            logger.error(f"Data source '{data_source_name}' not found")
            return False
        
        # Start data ingestion job
        logger.info("Starting ingestion job...")
        response = bedrock.start_ingestion_job(
            knowledgeBaseId=kb_id,
            dataSourceId=data_source_id
        )
        
        ingestion_job_id = response['ingestionJob']['ingestionJobId']
        logger.info(f"Started ingestion job: {ingestion_job_id}")
        
        # Always wait for job completion for simplicity
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
        
    except Exception as e:
        logger.error(f"Error syncing knowledge base: {str(e)}")
        return False

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Sync knowledge base with policy documents")
    parser.add_argument("--region", default="us-east-1", help="AWS region")
    parser.add_argument("--wait", action="store_true", help="Wait for job completion (always true now)")
    
    args = parser.parse_args()
    
    # Simplified function call with fewer parameters
    success = sync_knowledge_base(region=args.region)
    
    sys.exit(0 if success else 1)
