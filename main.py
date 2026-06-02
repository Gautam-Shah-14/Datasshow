from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import csv
import os
from typing import Optional

app = FastAPI(title="Student Data API", description="API to retrieve student data by enrollment number")

# Pydantic models
class EnrollmentRequest(BaseModel):
    enrollment: str

class StudentResponse(BaseModel):
    name: str
    enrollment: str
    department: str
    institute: str
    division: str
    email: str
    contact: str

def read_student_data():
    """Read student data from CSV file"""
    students = {}
    csv_file = "students.csv"
    
    if not os.path.exists(csv_file):
        raise HTTPException(status_code=500, detail="Student data file not found")
    
    try:
        with open(csv_file, 'r', newline='', encoding='utf-8') as file:
            reader = csv.DictReader(file)
            for row in reader:
                students[row['Enrollment']] = {
                    'name': row['Name'],
                    'enrollment': row['Enrollment'],
                    'department': row['Department'],
                    'institute': row['Institute'],
                    'division': row['Division'],
                    'email': row['email'],
                    'contact': row['contact']
                }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error reading student data: {str(e)}")
    
    return students

@app.get("/health")
async def root():
    return {"message": "Student Data API - Use POST /student to get student data by enrollment"}

@app.post("/student", response_model=StudentResponse)
async def get_student_data(request: EnrollmentRequest):
    """
    Retrieve student data by enrollment number
    """
    students = read_student_data()
    
    if request.enrollment not in students:
        raise HTTPException(
            status_code=404, 
            detail=f"Student with enrollment number {request.enrollment} not found"
        )
    
    return StudentResponse(**students[request.enrollment])

@app.get("/students")
async def get_all_students():
    """
    Get all students data
    """
    students = read_student_data()
    return {"students": list(students.values())}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
